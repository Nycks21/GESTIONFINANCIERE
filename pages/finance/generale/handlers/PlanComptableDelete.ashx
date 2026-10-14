<%@ WebHandler Language="C#" Class="PlanComptableDelete" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class PlanComptableDelete : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireCsrfSafePost(ctx, -1))
        { ctx.Response.StatusCode = 403; ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}"); return; }
        if (!AuthHelper.HasPermission("generale"))
        { ctx.Response.StatusCode = 403; ctx.Response.Write("{\"success\":false,\"message\":\"Permission refusée\"}"); return; }

        try
        {
            string json = new System.IO.StreamReader(ctx.Request.InputStream).ReadToEnd();
            var serializer = new JavaScriptSerializer();
            var data = serializer.Deserialize<Dictionary<string, object>>(json);
            if (data == null) { ctx.Response.Write("{\"success\":false,\"message\":\"Corps invalide.\"}"); return; }

            // ✅ Ordre (1..10) au lieu d'un GUID
            int ordre;
            if (!int.TryParse(GetString(data, "ordre"), out ordre) || ordre < 1 || ordre > 10)
            { ctx.Response.Write("{\"success\":false,\"message\":\"Ordre invalide (1..10).\"}"); return; }

            // ✅ Table dynamique : PLAN1..PLAN10
            string tableName = AuthHelperPlan.GetPlanTableName(ordre);

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // ─── 1. Vérifie l'existence du slot + récupère infos pour audit ───
                string code = "", nom = "";
                using (var cmd = new SqlCommand(
                    "SELECT CODE, NOM FROM FPLAN_HEADER WHERE ORDRE = @o", conn))
                {
                    cmd.Parameters.AddWithValue("@o", ordre);
                    using (var r = cmd.ExecuteReader())
                    {
                        if (!r.Read())
                        { ctx.Response.Write("{\"success\":false,\"message\":\"Slot introuvable.\"}"); return; }
                        code = r["CODE"] == DBNull.Value ? "" : r["CODE"].ToString();
                        nom  = r["NOM"]  == DBNull.Value ? "" : r["NOM"].ToString();
                    }
                }

                // ─── 2. 🔒 Vérifie qu'aucun élément n'est rattaché dans PLAN{ordre} ───
                string sqlCount = "SELECT COUNT(1) FROM " + tableName + " WHERE DELETION_AT IS NULL";
                using (var cmdEl = new SqlCommand(sqlCount, conn))
                {
                    int cnt = Convert.ToInt32(cmdEl.ExecuteScalar());
                    if (cnt > 0)
                    {
                        ctx.Response.Write(serializer.Serialize(new
                        {
                            success = false,
                            message = "Impossible de supprimer : ce plan contient " + cnt + " élément(s). "
                                    + "Supprimez-les d'abord."
                        }));
                        return;
                    }
                }

                // ─── 3. Réinitialisation du slot dans FPLAN_HEADER ───
                using (var cmd = new SqlCommand(@"
                    UPDATE FPLAN_HEADER
                    SET CODE = NULL,
                        NOM = NULL,
                        DESCRIPTION = NULL,
                        NIVEAU = 1,
                        PLAN_TYPE_CODE = NULL,
                        EST_PRINCIPAL = 0,
                        ACTIVE = 0,
                        UPDATED_BY = @uid,
                        UPDATED_AT = GETDATE()
                    WHERE ORDRE = @ordre", conn))
                {
                    cmd.Parameters.AddWithValue("@ordre", ordre);
                    cmd.Parameters.AddWithValue("@uid", userId);
                    cmd.ExecuteNonQuery();
                }

                // ─── 4. Audit ───
                try
                {
                    string ip = ctx.Request.UserHostAddress ?? "";
                    using (var cmdLog = new SqlCommand(@"
                        INSERT INTO SECURITY_LOG (USER_ID, ACTION, DETAILS, IP_ADDRESS, CREATED_AT)
                        VALUES (@uid, 'PLAN_DELETE', @det, @ip, GETDATE())", conn))
                    {
                        cmdLog.Parameters.AddWithValue("@uid", userId);
                        cmdLog.Parameters.AddWithValue("@det", "Slot reset: " + code + " - " + nom);
                        cmdLog.Parameters.AddWithValue("@ip", ip);
                        cmdLog.ExecuteNonQuery();
                    }
                }
                catch { }
            }

            ctx.Response.Write(serializer.Serialize(new
            {
                success = true,
                message = "Plan supprimé (slot réinitialisé)."
            }));
        }
        catch (SqlException sqlEx)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            { success = false, message = "SQL Error " + sqlEx.Number + " : " + sqlEx.Message }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            { success = false, message = ex.Message }));
        }
    }

    private string GetString(Dictionary<string, object> data, string key)
    { return data.ContainsKey(key) && data[key] != null ? data[key].ToString() : null; }

    public bool IsReusable { get { return false; } }
}

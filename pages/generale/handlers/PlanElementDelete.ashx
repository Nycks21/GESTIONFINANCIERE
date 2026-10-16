<%@ WebHandler Language="C#" Class="PlanElementDelete" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class PlanElementDelete : IHttpHandler, IRequiresSessionState
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

            string id = GetString(data, "id");
            int ordre;
            if (!int.TryParse(GetString(data, "planOrder"), out ordre) || ordre < 1 || ordre > 10)
            { ctx.Response.Write("{\"success\":false,\"message\":\"planOrder invalide.\"}"); return; }

            // ✅ C# 4.0 : variable nommée + exploitation
            Guid tmpId;
            if (string.IsNullOrEmpty(id) || !Guid.TryParse(id, out tmpId))
            { ctx.Response.Write("{\"success\":false,\"message\":\"ID invalide.\"}"); return; }

            string tableName = AuthHelperPlan.GetPlanTableName(ordre);
            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // ─── Vérif : enfants existants ? ───
                string sqlCh = "SELECT COUNT(1) FROM " + tableName +
                    " WHERE PARENT_ID = @id AND DELETION_AT IS NULL";
                using (var cmd = new SqlCommand(sqlCh, conn))
                {
                    cmd.Parameters.AddWithValue("@id", tmpId);
                    int enfants = Convert.ToInt32(cmd.ExecuteScalar());
                    if (enfants > 0)
                    {
                        ctx.Response.Write(serializer.Serialize(new
                        {
                            success = false,
                            message = "Impossible de supprimer : cet élément a " + enfants
                                    + " sous-élément(s). Supprimez-les d'abord."
                        }));
                        return;
                    }
                }

                // ─── Vérif : tiers rattachés ? ───
                using (var cmdTiers = new SqlCommand(@"
                    SELECT COUNT(1) FROM FTIERS
                    WHERE PLAN_ELEMENT_ID = @id AND PLAN_ORDER = @ordre AND DELETION_AT IS NULL", conn))
                {
                    cmdTiers.Parameters.AddWithValue("@id", tmpId);
                    cmdTiers.Parameters.AddWithValue("@ordre", ordre);
                    int nbTiers = Convert.ToInt32(cmdTiers.ExecuteScalar());
                    if (nbTiers > 0)
                    {
                        ctx.Response.Write(serializer.Serialize(new
                        {
                            success = false,
                            message = "Impossible de supprimer : " + nbTiers
                                    + " tiers sont rattachés à ce compte."
                        }));
                        return;
                    }
                }

                // ─── Soft delete ───
                string sql = @"
                    UPDATE " + tableName + @"
                    SET DELETION_AT = GETDATE(), DELETION_BY = @uid, ACTIVE = 0
                    WHERE ID = @id AND DELETION_AT IS NULL";
                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", tmpId);
                    cmd.Parameters.AddWithValue("@uid", userId);
                    int rows = cmd.ExecuteNonQuery();
                    if (rows == 0)
                    { ctx.Response.Write("{\"success\":false,\"message\":\"Élément introuvable.\"}"); return; }
                }

                // ─── Audit ───
                try
                {
                    string ip = ctx.Request.UserHostAddress ?? "";
                    using (var cmdLog = new SqlCommand(@"
                        INSERT INTO SECURITY_LOG (USER_ID, ACTION, DETAILS, IP_ADDRESS, CREATED_AT)
                        VALUES (@uid, 'ELEMENT_DELETE', @det, @ip, GETDATE())", conn))
                    {
                        cmdLog.Parameters.AddWithValue("@uid", userId);
                        cmdLog.Parameters.AddWithValue("@det", "PLAN" + ordre + " / ID=" + tmpId);
                        cmdLog.Parameters.AddWithValue("@ip", ip);
                        cmdLog.ExecuteNonQuery();
                    }
                }
                catch { }
            }

            ctx.Response.Write(serializer.Serialize(new { success = true, message = "Élément supprimé." }));
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

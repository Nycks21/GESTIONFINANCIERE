<%@ WebHandler Language="C#" Class="PlanComptableSave" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class PlanComptableSave : IHttpHandler, IRequiresSessionState
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
            if (data == null)
            { ctx.Response.Write("{\"success\":false,\"message\":\"Corps invalide.\"}"); return; }

            int ordre;
            if (!int.TryParse(GetString(data, "ordre"), out ordre) || ordre < 1 || ordre > 10)
            { ctx.Response.Write("{\"success\":false,\"message\":\"Ordre invalide (1..10).\"}"); return; }

            string code      = (GetString(data, "code") ?? "").Trim().ToUpperInvariant();
            string nom       = (GetString(data, "nom") ?? "").Trim();
            string desc      = (GetString(data, "description") ?? "").Trim();
            string typeCode  = GetString(data, "planTypeCode");
            bool   principal = GetBool(data, "estPrincipal", false);
            int    niveau;

            if (!int.TryParse(GetString(data, "niveau"), out niveau) || niveau < 1 || niveau > 10)
            { ctx.Response.Write("{\"success\":false,\"message\":\"Le niveau doit être entre 1 et 10.\"}"); return; }

            if (string.IsNullOrEmpty(code))
            { ctx.Response.Write("{\"success\":false,\"message\":\"Le code est obligatoire.\"}"); return; }
            if (string.IsNullOrEmpty(nom))
            { ctx.Response.Write("{\"success\":false,\"message\":\"Le nom est obligatoire.\"}"); return; }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // 🔒 Vérification : éléments présents dans PLAN{ordre} → verrou
                string tableName = AuthHelperPlan.GetPlanTableName(ordre);
                string sqlCount = "SELECT COUNT(*) FROM " + tableName + " WHERE DELETION_AT IS NULL";
                int elementCount = 0;
                using (var cmdCount = new SqlCommand(sqlCount, conn))
                {
                    elementCount = Convert.ToInt32(cmdCount.ExecuteScalar());
                }

                if (elementCount > 0)
                {
                    ctx.Response.Write(serializer.Serialize(new
                    {
                        success = false,
                        message = "Modification impossible : ce plan contient déjà "
                                + elementCount + " élément(s). Supprimez-les d'abord."
                    }));
                    return;
                }

                // Anti-doublon CODE (dans FPLAN_HEADER, hors slot courant)
                using (var cmdDup = new SqlCommand(@"
                    SELECT COUNT(1) FROM FPLAN_HEADER
                    WHERE CODE = @code AND ORDRE <> @ordre AND CODE IS NOT NULL AND CODE <> ''", conn))
                {
                    cmdDup.Parameters.AddWithValue("@code", code);
                    cmdDup.Parameters.AddWithValue("@ordre", ordre);
                    if (Convert.ToInt32(cmdDup.ExecuteScalar()) > 0)
                    { ctx.Response.Write("{\"success\":false,\"message\":\"Ce code de plan est déjà utilisé.\"}"); return; }
                }

                string sql = @"
                    UPDATE FPLAN_HEADER
                    SET CODE = @code,
                        NOM = @nom,
                        DESCRIPTION = @desc,
                        NIVEAU = @niveau,
                        PLAN_TYPE_CODE = @typeCode,
                        EST_PRINCIPAL = @principal,
                        UPDATED_BY = @userId,
                        UPDATED_AT = GETDATE()
                    WHERE ORDRE = @ordre";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@ordre", ordre);
                    cmd.Parameters.AddWithValue("@code", code);
                    cmd.Parameters.AddWithValue("@nom", nom);
                    cmd.Parameters.AddWithValue("@desc", string.IsNullOrEmpty(desc) ? (object)DBNull.Value : desc);
                    cmd.Parameters.AddWithValue("@niveau", niveau);
                    cmd.Parameters.AddWithValue("@typeCode", string.IsNullOrEmpty(typeCode) ? (object)DBNull.Value : typeCode);
                    cmd.Parameters.AddWithValue("@principal", principal ? 1 : 0);
                    cmd.Parameters.AddWithValue("@userId", userId);
                    cmd.ExecuteNonQuery();
                }

                LogSecurity(conn, userId, "PLAN_SAVE",
                    "Plan " + code + " (slot " + ordre + ") mis a jour");
            }

            ctx.Response.Write(serializer.Serialize(new
            {
                success = true,
                message = "Plan comptable enregistré avec succès."
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

    private void LogSecurity(SqlConnection conn, int userId, string action, string details)
    {
        try
        {
            string ip = HttpContext.Current.Request.UserHostAddress ?? "";
            using (var cmd = new SqlCommand(@"
                INSERT INTO SECURITY_LOG (USER_ID, ACTION, DETAILS, IP_ADDRESS, CREATED_AT)
                VALUES (@uid, @action, @details, @ip, GETDATE())", conn))
            {
                cmd.Parameters.AddWithValue("@uid", userId);
                cmd.Parameters.AddWithValue("@action", action);
                cmd.Parameters.AddWithValue("@details", details ?? "");
                cmd.Parameters.AddWithValue("@ip", ip);
                cmd.ExecuteNonQuery();
            }
        }
        catch { }
    }

    private string GetString(Dictionary<string, object> data, string key)
    { return data.ContainsKey(key) && data[key] != null ? data[key].ToString() : null; }
    private bool GetBool(Dictionary<string, object> data, string key, bool def)
    {
        if (data.ContainsKey(key) && data[key] != null)
        {
            bool v; if (bool.TryParse(data[key].ToString(), out v)) return v;
            string s = data[key].ToString().Trim();
            if (s == "1" || s == "true") return true;
            if (s == "0" || s == "false") return false;
        }
        return def;
    }

    public bool IsReusable { get { return false; } }
}

<%@ WebHandler Language="C#" Class="PlanComptableToggle" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class PlanComptableToggle : IHttpHandler, IRequiresSessionState
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
            { ctx.Response.Write("{\"success\":false,\"message\":\"Ordre invalide.\"}"); return; }

            bool activate = GetBool(data, "active", false);

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // Récupère infos actuelles
                string existingCode = null, existingNom = null;
                using (var cmd = new SqlCommand(
                    "SELECT CODE, NOM FROM FPLAN_HEADER WHERE ORDRE = @o", conn))
                {
                    cmd.Parameters.AddWithValue("@o", ordre);
                    using (var r = cmd.ExecuteReader())
                    {
                        if (!r.Read())
                        { ctx.Response.Write("{\"success\":false,\"message\":\"Slot introuvable.\"}"); return; }
                        existingCode = r["CODE"] == DBNull.Value ? "" : r["CODE"].ToString();
                        existingNom  = r["NOM"]  == DBNull.Value ? "" : r["NOM"].ToString();
                    }
                }

                if (activate && (string.IsNullOrEmpty(existingCode) || string.IsNullOrEmpty(existingNom)))
                {
                    ctx.Response.Write(serializer.Serialize(new
                    {
                        success = false,
                        message = "Impossible d'activer un plan vide. Renseignez d'abord un CODE et un NOM."
                    }));
                    return;
                }

                using (var cmd = new SqlCommand(@"
                    UPDATE FPLAN_HEADER
                    SET ACTIVE = @active,
                        UPDATED_BY = @userId,
                        UPDATED_AT = GETDATE()
                    WHERE ORDRE = @ordre", conn))
                {
                    cmd.Parameters.AddWithValue("@ordre", ordre);
                    cmd.Parameters.AddWithValue("@active", activate ? 1 : 0);
                    cmd.Parameters.AddWithValue("@userId", userId);
                    cmd.ExecuteNonQuery();
                }

                try
                {
                    string ip = ctx.Request.UserHostAddress ?? "";
                    using (var cmdLog = new SqlCommand(@"
                        INSERT INTO SECURITY_LOG (USER_ID, ACTION, DETAILS, IP_ADDRESS, CREATED_AT)
                        VALUES (@uid, @action, @details, @ip, GETDATE())", conn))
                    {
                        cmdLog.Parameters.AddWithValue("@uid", userId);
                        cmdLog.Parameters.AddWithValue("@action", activate ? "PLAN_ACTIVATE" : "PLAN_DEACTIVATE");
                        cmdLog.Parameters.AddWithValue("@details",
                            "Slot " + ordre + " (" + existingCode + " - " + existingNom + ")");
                        cmdLog.Parameters.AddWithValue("@ip", ip);
                        cmdLog.ExecuteNonQuery();
                    }
                }
                catch { }
            }

            ctx.Response.Write(serializer.Serialize(new
            {
                success = true,
                message = activate ? "Plan activé." : "Plan désactivé."
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

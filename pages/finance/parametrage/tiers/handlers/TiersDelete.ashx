<%@ WebHandler Language="C#" Class="TiersDelete" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class TiersDelete : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireCsrfSafePost(ctx, -1))
        { ctx.Response.StatusCode = 403; ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}"); return; }
        if (!AuthHelper.HasPermission("tiers"))
        { ctx.Response.StatusCode = 403; ctx.Response.Write("{\"success\":false,\"message\":\"Permission refusée\"}"); return; }

        try
        {
            string json = new System.IO.StreamReader(ctx.Request.InputStream).ReadToEnd();
            var serializer = new JavaScriptSerializer();
            var data = serializer.Deserialize<Dictionary<string, object>>(json);
            if (data == null) { ctx.Response.Write("{\"success\":false,\"message\":\"Corps invalide.\"}"); return; }

            string id = GetString(data, "id");
            Guid tmp;
            if (string.IsNullOrEmpty(id) || !Guid.TryParse(id, out tmp))
            { ctx.Response.Write("{\"success\":false,\"message\":\"ID invalide.\"}"); return; }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // Anti-suppression : écritures rattachées ?
                using (var cmdRef = new SqlCommand(
                    "SELECT COUNT(*) FROM FECRITURE_LIGNE WHERE TIERS_ID = @id", conn))
                {
                    cmdRef.Parameters.AddWithValue("@id", id);
                    int cnt = Convert.ToInt32(cmdRef.ExecuteScalar());
                    if (cnt > 0)
                    {
                        ctx.Response.Write(serializer.Serialize(new
                        {
                            success = false,
                            message = "Impossible de supprimer : " + cnt
                                    + " écriture(s) sont rattachées à ce tiers."
                        }));
                        return;
                    }
                }

                // Soft delete
                string sql = @"
                    UPDATE FTIERS
                    SET DELETION_AT = GETDATE(), DELETION_BY = @uid, ACTIVE = 0
                    WHERE ID = @id AND DELETION_AT IS NULL";
                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@uid", userId);
                    int rows = cmd.ExecuteNonQuery();
                    if (rows == 0)
                    { ctx.Response.Write("{\"success\":false,\"message\":\"Tiers introuvable.\"}"); return; }
                }

                try
                {
                    string ip = ctx.Request.UserHostAddress ?? "";
                    using (var cmdLog = new SqlCommand(@"
                        INSERT INTO SECURITY_LOG (USER_ID, ACTION, DETAILS, IP_ADDRESS, CREATED_AT)
                        VALUES (@uid, 'TIERS_DELETE', @det, @ip, GETDATE())", conn))
                    {
                        cmdLog.Parameters.AddWithValue("@uid", userId);
                        cmdLog.Parameters.AddWithValue("@det", "Tiers ID: " + id);
                        cmdLog.Parameters.AddWithValue("@ip", ip);
                        cmdLog.ExecuteNonQuery();
                    }
                }
                catch { }
            }

            ctx.Response.Write(serializer.Serialize(new
            { success = true, message = "Tiers supprimé." }));
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

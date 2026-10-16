<%@ WebHandler Language="C#" Class="JournalDelete" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class JournalDelete : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireCsrfSafePost(ctx, -1))
        { ctx.Response.StatusCode = 403; ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}"); return; }
        if (!AuthHelper.HasPermission("journaux"))
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

                using (var cmdRef = new SqlCommand(
                    "SELECT COUNT(*) FROM FECRITURE WHERE JOURNAL_ID = @id", conn))
                {
                    cmdRef.Parameters.AddWithValue("@id", id);
                    int cnt = Convert.ToInt32(cmdRef.ExecuteScalar());
                    if (cnt > 0)
                    {
                        ctx.Response.Write(serializer.Serialize(new
                        {
                            success = false,
                            message = "Impossible de supprimer : " + cnt
                                    + " écriture(s) sont rattachées à ce journal."
                        }));
                        return;
                    }
                }

                // Supprime les liaisons sites
                using (var cmdDelJs = new SqlCommand(
                    "DELETE FROM FJOURNAL_SITE WHERE JOURNAL_ID = @id", conn))
                {
                    cmdDelJs.Parameters.AddWithValue("@id", id);
                    cmdDelJs.ExecuteNonQuery();
                }

                string sql = @"
                    UPDATE FJOURNAL
                    SET DELETION_AT = GETDATE(), DELETION_BY = @uid, ACTIVE = 0
                    WHERE ID = @id AND DELETION_AT IS NULL";
                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@uid", userId);
                    int rows = cmd.ExecuteNonQuery();
                    if (rows == 0)
                    { ctx.Response.Write("{\"success\":false,\"message\":\"Journal introuvable.\"}"); return; }
                }

                try
                {
                    string ip = ctx.Request.UserHostAddress ?? "";
                    using (var cmdLog = new SqlCommand(@"
                        INSERT INTO SECURITY_LOG (USER_ID, ACTION, DETAILS, IP_ADDRESS, CREATED_AT)
                        VALUES (@uid, 'JOURNAL_DELETE', @det, @ip, GETDATE())", conn))
                    {
                        cmdLog.Parameters.AddWithValue("@uid", userId);
                        cmdLog.Parameters.AddWithValue("@det", "Journal ID: " + id);
                        cmdLog.Parameters.AddWithValue("@ip", ip);
                        cmdLog.ExecuteNonQuery();
                    }
                }
                catch { }
            }

            ctx.Response.Write(serializer.Serialize(new
            { success = true, message = "Journal supprimé." }));
        }
        catch (SqlException sqlEx)
        {
            if (sqlEx.Number == 547)
            {
                ctx.Response.Write(new JavaScriptSerializer().Serialize(new
                { success = false, message = "Impossible : ce journal est référencé ailleurs." }));
                return;
            }
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

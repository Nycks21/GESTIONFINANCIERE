<%@ WebHandler Language="C#" Class="GetMonnaieByCode" %>
using System;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetMonnaieByCode : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireApiAuth(ctx, -1))
        {
            ctx.Response.StatusCode = 403;
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            string code = (ctx.Request.QueryString["code"] ?? "").Trim().ToUpperInvariant();
            string excludeId = (ctx.Request.QueryString["excludeId"] ?? "").Trim();

            if (string.IsNullOrEmpty(code))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Code manquant.\"}");
                return;
            }

            string connStr = AuthHelper.ConnectionString;
            int exists = 0;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                string sql = "SELECT COUNT(1) FROM FMONNAIE WHERE CODE = @code AND DELETION_AT IS NULL";
                if (!string.IsNullOrEmpty(excludeId))
                    sql += " AND ID <> @excludeId";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@code", code);
                    if (!string.IsNullOrEmpty(excludeId))
                        cmd.Parameters.AddWithValue("@excludeId", excludeId);
                    exists = Convert.ToInt32(cmd.ExecuteScalar());
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = true,
                available = exists == 0
            }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = false,
                message = ex.Message.Replace("\"", "\\\"")
            }));
        }
    }

    public bool IsReusable { get { return false; } }
}

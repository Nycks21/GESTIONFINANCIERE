<%@ WebHandler Language="C#" Class="GetMonnaieStats" %>
using System;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetMonnaieStats : IHttpHandler, IRequiresSessionState
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
            string connStr = AuthHelper.ConnectionString;
            int total = 0, actives = 0, inactives = 0, reference = 0;

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                string sql = @"
                    SELECT
                        COUNT(*) AS Total,
                        SUM(CASE WHEN ACTIVE = 1 THEN 1 ELSE 0 END) AS Actives,
                        SUM(CASE WHEN ACTIVE = 0 THEN 1 ELSE 0 END) AS Inactives,
                        SUM(CASE WHEN EST_REFERENCE = 1 THEN 1 ELSE 0 END) AS Reference
                    FROM FMONNAIE
                    WHERE DELETION_AT IS NULL";
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                using (SqlDataReader reader = cmd.ExecuteReader())
                {
                    if (reader.Read())
                    {
                        total = Convert.ToInt32(reader["Total"]);
                        actives = reader["Actives"] == DBNull.Value ? 0 : Convert.ToInt32(reader["Actives"]);
                        inactives = reader["Inactives"] == DBNull.Value ? 0 : Convert.ToInt32(reader["Inactives"]);
                        reference = reader["Reference"] == DBNull.Value ? 0 : Convert.ToInt32(reader["Reference"]);
                    }
                }
            }

            var result = new { success = true, total = total, actives = actives, inactives = inactives, reference = reference };
            ctx.Response.Write(new JavaScriptSerializer().Serialize(result));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    public bool IsReusable { get { return false; } }
}

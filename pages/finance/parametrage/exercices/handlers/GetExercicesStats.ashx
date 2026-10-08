<%@ WebHandler Language="C#" Class="GetExercicesStats" %>
using System;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetExercicesStats : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireApiPermission(ctx, "exercices"))
        {
            ctx.Response.StatusCode = 403;
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            string connStr = AuthHelper.ConnectionString;
            int total = 0, ouverts = 0, clotures = 0, archives = 0;

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                string sql = @"
                    SELECT
                        COUNT(*) AS Total,
                        SUM(CASE WHEN STATUT = 'OUVERT'  THEN 1 ELSE 0 END) AS Ouverts,
                        SUM(CASE WHEN STATUT = 'CLOTURE' THEN 1 ELSE 0 END) AS Clotures,
                        SUM(CASE WHEN STATUT = 'ARCHIVE' THEN 1 ELSE 0 END) AS Archives
                    FROM FEXERCICE
                    WHERE DELETION_AT IS NULL";
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                using (SqlDataReader reader = cmd.ExecuteReader())
                {
                    if (reader.Read())
                    {
                        total    = Convert.ToInt32(reader["Total"]);
                        ouverts  = reader["Ouverts"]  == DBNull.Value ? 0 : Convert.ToInt32(reader["Ouverts"]);
                        clotures = reader["Clotures"] == DBNull.Value ? 0 : Convert.ToInt32(reader["Clotures"]);
                        archives = reader["Archives"] == DBNull.Value ? 0 : Convert.ToInt32(reader["Archives"]);
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = true, total = total, ouverts = ouverts, clotures = clotures, archives = archives
            }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = false, message = ex.Message
            }));
        }
    }

    public bool IsReusable { get { return false; } }
}

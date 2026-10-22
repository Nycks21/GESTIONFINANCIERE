<%@ WebHandler Language="C#" Class="GetDemandesStats" %>
using System;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetDemandesStats : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        try
        {
            // ⭐ Auth DANS le try pour capturer toute exception
            if (!AuthHelper.RequireApiAuth(ctx, -1))
            {
                ctx.Response.StatusCode = 403;
                ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
                return;
            }

            string connStr = AuthHelper.ConnectionString;
            if (string.IsNullOrWhiteSpace(connStr))
            {
                ctx.Response.StatusCode = 500;
                ctx.Response.Write(new JavaScriptSerializer().Serialize(new
                {
                    success = false,
                    message = "Chaîne de connexion non configurée."
                }));
                return;
            }

            int userId = AuthHelper.GetUserId(ctx);
            int total = 0, valide = 0, brouillon = 0, annule = 0;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // ⭐ Pas de 'PENDING' — CHECK SSORTIE = BROUILLON, VALIDE, ANNULE, TERMINE
                string sql = @"
                    SELECT
                        COUNT(*) AS Total,
                        SUM(CASE WHEN STATUT = 'VALIDE'    THEN 1 ELSE 0 END) AS Valide,
                        SUM(CASE WHEN STATUT = 'BROUILLON' THEN 1 ELSE 0 END) AS Brouillon,
                        SUM(CASE WHEN STATUT = 'ANNULE'    THEN 1 ELSE 0 END) AS Annule
                    FROM SSORTIE
                    WHERE DELETION_AT IS NULL
                      AND CREATED_BY = @userId";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@userId", userId);
                    using (var reader = cmd.ExecuteReader())
                    {
                        if (reader.Read())
                        {
                            total     = reader["Total"]     == DBNull.Value ? 0 : Convert.ToInt32(reader["Total"]);
                            valide    = reader["Valide"]    == DBNull.Value ? 0 : Convert.ToInt32(reader["Valide"]);
                            brouillon = reader["Brouillon"] == DBNull.Value ? 0 : Convert.ToInt32(reader["Brouillon"]);
                            annule    = reader["Annule"]    == DBNull.Value ? 0 : Convert.ToInt32(reader["Annule"]);
                        }
                    }
                }
            }

            var response = new { success = true, total, valide, brouillon, annule };
            ctx.Response.Write(new JavaScriptSerializer().Serialize(response));
        }
        catch (SqlException sex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success  = false,
                sqlError = sex.Number,
                message  = "Erreur SQL (" + sex.Number + ") : " + sex.Message.Replace("\"", "\\\"")
            }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success   = false,
                errorType = ex.GetType().FullName,
                message   = "Erreur serveur : " + ex.Message.Replace("\"", "\\\"")
            }));
        }
    }

    public bool IsReusable { get { return false; } }
}

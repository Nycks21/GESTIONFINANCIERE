<%@ WebHandler Language="C#" Class="GetSortieStats" %>
using System;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetSortieStats : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        try
        {
            // ⭐ RequireApiAuth déplacé DANS le try pour capturer toute exception
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
                    message = "Chaîne de connexion non configurée (AuthHelper.ConnectionString vide)."
                }));
                return;
            }

            int total = 0, valide = 0, brouillon = 0, annule = 0, pending = 0;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // ⭐ 'PENDING' n'existe pas dans la CHECK de SSORTIE (BROUILLON, VALIDE, ANNULE, TERMINE)
                //    → on utilise 'BROUILLON' seul pour le badge "en attente"
                string sql = @"
                    SELECT
                        COUNT(*) AS Total,
                        SUM(CASE WHEN STATUT = 'VALIDE'    THEN 1 ELSE 0 END) AS Valide,
                        SUM(CASE WHEN STATUT = 'BROUILLON' THEN 1 ELSE 0 END) AS Brouillon,
                        SUM(CASE WHEN STATUT = 'ANNULE'    THEN 1 ELSE 0 END) AS Annule,
                        SUM(CASE WHEN STATUT IN ('BROUILLON', 'TERMINE') THEN 1 ELSE 0 END) AS Pending
                    FROM SSORTIE
                    WHERE DELETION_AT IS NULL";

                using (var cmd = new SqlCommand(sql, conn))
                using (var reader = cmd.ExecuteReader())
                {
                    if (reader.Read())
                    {
                        total     = ToInt32(reader["Total"]);
                        valide    = ToInt32(reader["Valide"]);
                        brouillon = ToInt32(reader["Brouillon"]);
                        annule    = ToInt32(reader["Annule"]);
                        pending   = ToInt32(reader["Pending"]);
                    }
                }
            }

            var response = new { success = true, total, valide, brouillon, annule, pending };
            ctx.Response.Write(new JavaScriptSerializer().Serialize(response));
        }
        catch (SqlException sex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success   = false,
                sqlError  = sex.Number,
                sqlState  = sex.State,
                sqlLine   = sex.LineNumber,
                message   = "Erreur SQL (" + sex.Number + ") : "
                            + sex.Message.Replace("\"", "\\\"")
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
                            // ⚠️ Stack trace uniquement en DEV — retirer en production
                            + " | Stack : " + (ex.StackTrace ?? "").Replace("\"", "\\\"")
            }));
        }
    }

    private static int ToInt32(object value)
    {
        return value == DBNull.Value || value == null ? 0 : Convert.ToInt32(value);
    }

    public bool IsReusable { get { return false; } }
}

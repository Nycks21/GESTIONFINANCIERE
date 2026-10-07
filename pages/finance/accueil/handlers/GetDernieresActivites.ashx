<%@ WebHandler Language="C#" Class="GetDernieresActivites" %>

using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.SessionState;
using System.Web.Script.Serialization;

public class GetDernieresActivites : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext context)
    {
        context.Response.ContentType = "application/json; charset=utf-8";
        context.Response.Cache.SetNoStore();

        try
        {
            if (!AuthHelper.RequireApiAuth(context, -1))
            {
                context.Response.StatusCode = 401;
                context.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
                return;
            }

            var list = new List<Dictionary<string, object>>();

            using (var conn = new SqlConnection(AuthHelper.ConnectionString))
            {
                conn.Open();

                const string sql = @"
                    SELECT TOP 10
                           E.ID,
                           E.NUMERO,
                           E.LIBELLE,
                           E.STATUT,
                           E.DATE_COMPTABLE,
                           E.CREATED_AT,
                           J.LIBELLE AS JOURNAL,
                           U.USERNAME AS UTILISATEUR
                      FROM FECRITURE E
                      INNER JOIN FJOURNAL J ON J.ID = E.JOURNAL_ID
                      LEFT  JOIN USERS    U ON U.IDUSER = E.CREATED_BY
                     ORDER BY E.CREATED_AT DESC";

                using (var cmd = new SqlCommand(sql, conn))
                using (var r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        list.Add(new Dictionary<string, object>
                        {
                            { "id",         r["ID"].ToString() },
                            { "numero",     r["NUMERO"].ToString() },
                            { "libelle",    r["LIBELLE"].ToString() },
                            { "statut",     r["STATUT"].ToString() },
                            { "journal",    r["JOURNAL"].ToString() },
                            { "date",       Convert.ToDateTime(r["DATE_COMPTABLE"]).ToString("yyyy-MM-dd") },
                            { "createdAt",  Convert.ToDateTime(r["CREATED_AT"]).ToString("o") },
                            { "user",       r["UTILISATEUR"] == DBNull.Value ? "" : r["UTILISATEUR"].ToString() }
                        });
                    }
                }
            }

            context.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = true,
                data = list
            }));
        }
        catch (Exception ex)
        {
            context.Response.StatusCode = 500;
            context.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = false,
                message = ex.Message
            }));
        }
    }

    public bool IsReusable { get { return false; } }
}

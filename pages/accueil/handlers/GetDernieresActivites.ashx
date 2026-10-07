<%@ WebHandler Language="C#" Class="GetDernieresActivites" %>

using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.SessionState;
using System.Web.Script.Serialization;
using GESTIONFINANCIERE.App_code;

public class GetDernieresActivites : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext context)
    {
        context.Response.ContentType = "application/json";

        try
        {
            if (!AuthHelper.IsAuthenticated(context)) { context.Response.StatusCode = 401; return; }
            FinanceHelper.RequirePermission(context, FinanceHelper.PERM_RAPPORT_READ);

            var activites = new List<object>();
            string sql = @"
                SELECT TOP 5
                       E.ID, E.NUMERO, E.LIBELLE, E.STATUT,
                       E.DATE_COMPTABLE, E.CREATED_AT,
                       J.LIBELLE AS JOURNAL,
                       U.USERNAME AS UTILISATEUR
                  FROM FECRITURE E
                  INNER JOIN FJOURNAL J ON J.ID = E.JOURNAL_ID
                  LEFT  JOIN USERS    U ON U.IDUSER = E.CREATED_BY
                 ORDER BY E.CREATED_AT DESC;";

            using (var cn = new SqlConnection(AuthHelper.GetConnectionString()))
            using (var cmd = new SqlCommand(sql, cn))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    while (rd.Read())
                    {
                        activites.Add(new
                        {
                            id        = rd["ID"].ToString(),
                            numero    = rd["NUMERO"].ToString(),
                            libelle   = rd["LIBELLE"].ToString(),
                            statut    = rd["STATUT"].ToString(),
                            journal   = rd["JOURNAL"].ToString(),
                            user      = rd["UTILISATEUR"] == DBNull.Value ? "" : rd["UTILISATEUR"].ToString(),
                            createdAt = Convert.ToDateTime(rd["CREATED_AT"]).ToString("yyyy-MM-dd HH:mm")
                        });
                    }
                }
            }

            context.Response.Write(new JavaScriptSerializer().Serialize(activites));
        }
        catch (Exception ex)
        {
            Logger.Error("GetDernieresActivites", ex);
            context.Response.StatusCode = 500;
            context.Response.Write("{\"error\":\"Erreur serveur\"}");
        }
    }

    public bool IsReusable => false;
}

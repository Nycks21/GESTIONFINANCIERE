<%@ WebHandler Language="C#" Class="GetFinanceStats" %>

using System;
using System.Data;
using System.Data.SqlClient;
using System.Web;
using System.Web.SessionState;
using System.Web.Script.Serialization;
using GESTIONFINANCIERE.App_code;

public class GetFinanceStats : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext context)
    {
        context.Response.ContentType = "application/json";

        try
        {
            // ---- Authentification + permission ----
            if (!AuthHelper.IsAuthenticated(context))
            {
                context.Response.StatusCode = 401;
                context.Response.Write("{\"error\":\"Non authentifié\"}");
                return;
            }
            FinanceHelper.RequirePermission(context, FinanceHelper.PERM_RAPPORT_READ);

            // ---- Requête ----
            string cs = AuthHelper.GetConnectionString();
            var result = new
            {
                soldeActuel    = 0m,
                ecrituresMois  = 0,
                entreesTotales = 0m,
                sortiesTotales = 0m
            };

            using (var cn = new SqlConnection(cs))
            using (var cmd = new SqlCommand("SELECT * FROM VW_FINANCE_STATS_DASHBOARD", cn))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    if (rd.Read())
                    {
                        result = new
                        {
                            soldeActuel    = rd["SOLDE_ACTUEL"]    == DBNull.Value ? 0m : Convert.ToDecimal(rd["SOLDE_ACTUEL"]),
                            ecrituresMois  = rd["ECRITURES_MOIS"]  == DBNull.Value ? 0  : Convert.ToInt32(rd["ECRITURES_MOIS"]),
                            entreesTotales = rd["ENTREES_TOTALES"] == DBNull.Value ? 0m : Convert.ToDecimal(rd["ENTREES_TOTALES"]),
                            sortiesTotales = rd["SORTIES_TOTALES"] == DBNull.Value ? 0m : Convert.ToDecimal(rd["SORTIES_TOTALES"])
                        };
                    }
                }
            }

            context.Response.Write(new JavaScriptSerializer().Serialize(result));
        }
        catch (UnauthorizedAccessException ex)
        {
            context.Response.StatusCode = 403;
            context.Response.Write("{\"error\":\"" + ex.Message.Replace("\"", "'") + "\"}");
        }
        catch (Exception ex)
        {
            Logger.Error("GetFinanceStats", ex);
            context.Response.StatusCode = 500;
            context.Response.Write("{\"error\":\"Erreur serveur\"}");
        }
    }

    public bool IsReusable => false;
}

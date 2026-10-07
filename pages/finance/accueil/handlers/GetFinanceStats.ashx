<%@ WebHandler Language="C#" Class="GetFinanceStats" %>

using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.SessionState;
using System.Web.Script.Serialization;

public class GetFinanceStats : IHttpHandler, IRequiresSessionState
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

            var result = new Dictionary<string, object>();

            using (var conn = new SqlConnection(AuthHelper.ConnectionString))
            {
                conn.Open();

                // Solde trésorerie (comptes classe 5)
                const string sqlSolde = @"
                    SELECT ISNULL(SUM(L.DEBIT - L.CREDIT), 0)
                      FROM FECRITURE_LIGNE L
                      INNER JOIN FECRITURE      E  ON E.ID  = L.ECRITURE_ID
                      INNER JOIN FPLAN_ELEMENT PE  ON PE.ID = L.COMPTE_ID
                     WHERE E.STATUT IN ('VALIDEE','COMPTABILISEE')
                       AND PE.CODE LIKE '5%'";
                using (var cmd = new SqlCommand(sqlSolde, conn))
                    result["solde"] = Convert.ToDecimal(cmd.ExecuteScalar());

                // Écritures du mois
                const string sqlEcr = @"
                    SELECT COUNT(*) AS TOTAL,
                           SUM(CASE WHEN STATUT='BROUILLON' THEN 1 ELSE 0 END) AS BROUILLONS,
                           SUM(CASE WHEN STATUT='A_VALIDER' THEN 1 ELSE 0 END) AS AVALIDER
                      FROM FECRITURE
                     WHERE MONTH(DATE_COMPTABLE) = MONTH(GETDATE())
                       AND YEAR(DATE_COMPTABLE)  = YEAR(GETDATE())";
                using (var cmd = new SqlCommand(sqlEcr, conn))
                using (var r = cmd.ExecuteReader())
                {
                    if (r.Read())
                    {
                        result["ecrituresMois"] = r["TOTAL"]      == DBNull.Value ? 0 : Convert.ToInt32(r["TOTAL"]);
                        result["brouillons"]    = r["BROUILLONS"] == DBNull.Value ? 0 : Convert.ToInt32(r["BROUILLONS"]);
                        result["aValider"]      = r["AVALIDER"]   == DBNull.Value ? 0 : Convert.ToInt32(r["AVALIDER"]);
                    }
                    r.Close();
                }

                // Débits/Crédits du mois
                const string sqlMvt = @"
                    SELECT ISNULL(SUM(TOTAL_DEBIT),0)  AS DEBITS,
                           ISNULL(SUM(TOTAL_CREDIT),0) AS CREDITS
                      FROM FECRITURE
                     WHERE STATUT IN ('VALIDEE','COMPTABILISEE')
                       AND MONTH(DATE_COMPTABLE) = MONTH(GETDATE())
                       AND YEAR(DATE_COMPTABLE)  = YEAR(GETDATE())";
                using (var cmd = new SqlCommand(sqlMvt, conn))
                using (var r = cmd.ExecuteReader())
                {
                    if (r.Read())
                    {
                        result["debits"]  = Convert.ToDecimal(r["DEBITS"]);
                        result["credits"] = Convert.ToDecimal(r["CREDITS"]);
                    }
                    r.Close();
                }
            }

            result["success"] = true;
            context.Response.Write(new JavaScriptSerializer().Serialize(result));
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

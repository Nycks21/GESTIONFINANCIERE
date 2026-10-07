<%@ WebHandler Language="C#" Class="GetChartData" %>

using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.SessionState;
using System.Web.Script.Serialization;
using GESTIONFINANCIERE.App_code;

public class GetChartData : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext context)
    {
        context.Response.ContentType = "application/json";

        try
        {
            if (!AuthHelper.IsAuthenticated(context)) { context.Response.StatusCode = 401; return; }
            FinanceHelper.RequirePermission(context, FinanceHelper.PERM_RAPPORT_READ);

            string type = context.Request["type"] ?? "evolution";
            var data = new Dictionary<string, object>();

            using (var cn = new SqlConnection(AuthHelper.GetConnectionString()))
            {
                cn.Open();

                if (type == "evolution")
                {
                    // Entrées / Sorties par mois sur l'année en cours
                    string sql = @"
                        SELECT MONTH(E.DATE_COMPTABLE) AS MOIS,
                               ISNULL(SUM(E.TOTAL_DEBIT),0)  AS ENTREES,
                               ISNULL(SUM(E.TOTAL_CREDIT),0) AS SORTIES
                          FROM FECRITURE E
                         WHERE E.STATUT IN ('VALIDEE','COMPTABILISEE')
                           AND YEAR(E.DATE_COMPTABLE) = YEAR(GETDATE())
                         GROUP BY MONTH(E.DATE_COMPTABLE)
                         ORDER BY MOIS;";
                    var mois = new List<int>();
                    var entrees = new List<decimal>();
                    var sorties = new List<decimal>();

                    using (var cmd = new SqlCommand(sql, cn))
                    using (var rd = cmd.ExecuteReader())
                    {
                        while (rd.Read())
                        {
                            mois.Add(Convert.ToInt32(rd["MOIS"]));
                            entrees.Add(Convert.ToDecimal(rd["ENTREES"]));
                            sorties.Add(Convert.ToDecimal(rd["SORTIES"]));
                        }
                    }
                    data["mois"]    = mois;
                    data["entrees"] = entrees;
                    data["sorties"] = sorties;
                }
                else if (type == "depenses")
                {
                    // Répartition par catégorie (via axe CATEGORIES_FINANCIERES ou comptes classe 6)
                    string sql = @"
                        SELECT ISNULL(PE.LIBELLE,'Non classé') AS CATEGORIE,
                               ISNULL(SUM(L.DEBIT),0) AS MONTANT
                          FROM FECRITURE_LIGNE L
                          INNER JOIN FECRITURE E ON E.ID = L.ECRITURE_ID
                          INNER JOIN FPLAN_ELEMENT PE ON PE.ID = L.COMPTE_ID
                         WHERE E.STATUT IN ('VALIDEE','COMPTABILISEE')
                           AND PE.CODE LIKE '6%'
                           AND MONTH(E.DATE_COMPTABLE) = MONTH(GETDATE())
                         GROUP BY PE.LIBELLE
                         ORDER BY MONTANT DESC;";
                    var labels  = new List<string>();
                    var valeurs = new List<decimal>();

                    using (var cmd = new SqlCommand(sql, cn))
                    using (var rd = cmd.ExecuteReader())
                    {
                        while (rd.Read())
                        {
                            labels.Add(rd["CATEGORIE"].ToString());
                            valeurs.Add(Convert.ToDecimal(rd["MONTANT"]));
                        }
                    }
                    data["labels"]  = labels;
                    data["valeurs"] = valeurs;
                }
            }

            context.Response.Write(new JavaScriptSerializer().Serialize(data));
        }
        catch (Exception ex)
        {
            Logger.Error("GetChartData", ex);
            context.Response.StatusCode = 500;
            context.Response.Write("{\"error\":\"Erreur serveur\"}");
        }
    }

    public bool IsReusable => false;
}

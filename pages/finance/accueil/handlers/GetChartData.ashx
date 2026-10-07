<%@ WebHandler Language="C#" Class="GetChartData" %>

using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.SessionState;
using System.Web.Script.Serialization;

public class GetChartData : IHttpHandler, IRequiresSessionState
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

            string type = context.Request["type"] ?? "evolution";
            var data = new Dictionary<string, object>();

            using (var conn = new SqlConnection(AuthHelper.ConnectionString))
            {
                conn.Open();

                if (type == "evolution")
                {
                    const string sql = @"
                        SELECT MONTH(DATE_COMPTABLE) AS M,
                               ISNULL(SUM(TOTAL_DEBIT),0)  AS E,
                               ISNULL(SUM(TOTAL_CREDIT),0) AS S
                          FROM FECRITURE
                         WHERE STATUT IN ('VALIDEE','COMPTABILISEE')
                           AND YEAR(DATE_COMPTABLE) = YEAR(GETDATE())
                         GROUP BY MONTH(DATE_COMPTABLE)
                         ORDER BY M";

                    var entrees = new decimal[12];
                    var sorties = new decimal[12];

                    using (var cmd = new SqlCommand(sql, conn))
                    using (var r = cmd.ExecuteReader())
                    {
                        while (r.Read())
                        {
                            int m = Convert.ToInt32(r["M"]) - 1;
                            if (m >= 0 && m < 12)
                            {
                                entrees[m] = Convert.ToDecimal(r["E"]);
                                sorties[m] = Convert.ToDecimal(r["S"]);
                            }
                        }
                    }

                    data["labels"]  = new[] { "Jan","Fév","Mar","Avr","Mai","Jun","Jul","Aoû","Sep","Oct","Nov","Déc" };
                    data["entrees"] = entrees;
                    data["sorties"] = sorties;
                }
                else if (type == "repartition")
                {
                    const string sql = @"
                        SELECT ISNULL(PE.LIBELLE,'Non classé') AS LIB,
                               ISNULL(SUM(L.DEBIT),0)          AS MONTANT
                          FROM FECRITURE_LIGNE L
                          INNER JOIN FECRITURE      E  ON E.ID  = L.ECRITURE_ID
                          INNER JOIN FPLAN_ELEMENT  PE ON PE.ID = L.COMPTE_ID
                         WHERE E.STATUT IN ('VALIDEE','COMPTABILISEE')
                           AND PE.CODE LIKE '6%'
                           AND MONTH(E.DATE_COMPTABLE) = MONTH(GETDATE())
                           AND YEAR(E.DATE_COMPTABLE)  = YEAR(GETDATE())
                         GROUP BY PE.LIBELLE
                         HAVING SUM(L.DEBIT) > 0
                         ORDER BY MONTANT DESC";

                    var labels  = new List<string>();
                    var valeurs = new List<decimal>();

                    using (var cmd = new SqlCommand(sql, conn))
                    using (var r = cmd.ExecuteReader())
                    {
                        int i = 0;
                        while (r.Read() && i < 6)
                        {
                            labels.Add(r["LIB"].ToString());
                            valeurs.Add(Convert.ToDecimal(r["MONTANT"]));
                            i++;
                        }
                    }

                    data["labels"]  = labels;
                    data["valeurs"] = valeurs;
                }
            }

            data["success"] = true;
            context.Response.Write(new JavaScriptSerializer().Serialize(data));
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

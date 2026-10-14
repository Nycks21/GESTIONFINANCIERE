<%@ WebHandler Language="C#" Class="GetJournauxLookups" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetJournauxLookups : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireApiPermission(ctx, "journaux"))
        {
            ctx.Response.StatusCode = 403;
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            string connStr = AuthHelper.ConnectionString;
            var sites = new List<Dictionary<string, object>>();
            var monnaies = new List<Dictionary<string, object>>();
            var comptesBanque = new List<Dictionary<string, object>>();

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                // Sites actifs
                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT ID, CODE, NOM FROM FSITE
                    WHERE ACTIVE = 1 AND DELETION_AT IS NULL
                    ORDER BY CODE", conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        var d = new Dictionary<string, object>();
                        d["ID"]   = r["ID"].ToString();
                        d["CODE"] = r["CODE"].ToString();
                        d["NOM"]  = r["NOM"].ToString();
                        sites.Add(d);
                    }
                }

                // Monnaies actives
                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT ID, CODE, NOM FROM FMONNAIE
                    WHERE ACTIVE = 1 AND DELETION_AT IS NULL
                    ORDER BY CODE", conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        var d = new Dictionary<string, object>();
                        d["ID"]   = r["ID"].ToString();
                        d["CODE"] = r["CODE"].ToString();
                        d["NOM"]  = r["NOM"].ToString();
                        monnaies.Add(d);
                    }
                }

                // Comptes bancaires : éléments DETAIL de plans COMPTABLE actifs
                // via la vue VW_ALL_PLAN_ELEMENTS (union des 10 tables)
                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT e.ID, e.CODE, e.LIBELLE, e.NIVEAU,
                           e.PLAN_ORDER,
                           h.CODE AS PLAN_CODE
                    FROM VW_ALL_PLAN_ELEMENTS e
                    INNER JOIN FPLAN_HEADER h ON h.ORDRE = e.PLAN_ORDER
                    WHERE e.ACTIVE = 1
                      AND h.ACTIVE = 1
                      AND h.PLAN_TYPE_CODE = 'COMPTABLE'
                    ORDER BY e.PLAN_ORDER, e.CODE", conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        var d = new Dictionary<string, object>();
                        d["ID"]         = r["ID"].ToString();
                        d["CODE"]       = r["CODE"].ToString();
                        d["LIBELLE"]    = r["LIBELLE"].ToString();
                        d["NIVEAU"]     = Convert.ToInt32(r["NIVEAU"]);
                        d["PLAN_ORDER"] = Convert.ToInt32(r["PLAN_ORDER"]);
                        d["PLAN_CODE"]  = r["PLAN_CODE"] == DBNull.Value ? "" : r["PLAN_CODE"].ToString();
                        comptesBanque.Add(d);
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = true,
                sites = sites,
                monnaies = monnaies,
                comptesBanque = comptesBanque
            }));
        }
        catch (SqlException sqlEx)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            { success = false, message = "SQL Error " + sqlEx.Number + " : " + sqlEx.Message }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            { success = false, message = ex.Message }));
        }
    }

    public bool IsReusable { get { return false; } }
}

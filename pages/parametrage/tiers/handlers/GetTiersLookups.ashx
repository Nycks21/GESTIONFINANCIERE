<%@ WebHandler Language="C#" Class="GetTiersLookups" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetTiersLookups : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireApiPermission(ctx, "tiers"))
        {
            ctx.Response.StatusCode = 403;
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            string connStr = AuthHelper.ConnectionString;
            var comptes = new List<Dictionary<string, object>>();

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                // ✅ VW_ALL_PLAN_ELEMENTS : union des 10 tables PLAN1..PLAN10
                // Seuls les comptes de DERNIER niveau (pas d'enfants) + auxiliaire + actif
                string sql = @"
                    SELECT e.ID, e.CODE, e.LIBELLE, e.NIVEAU,
                           e.PLAN_ORDER,
                           h.CODE AS PLAN_CODE,
                           h.NOM  AS PLAN_NOM
                    FROM VW_ALL_PLAN_ELEMENTS e
                    INNER JOIN FPLAN_HEADER h ON h.ORDRE = e.PLAN_ORDER
                    WHERE e.EST_AUXILIAIRE = 1
                      AND e.ACTIVE = 1
                      AND h.ACTIVE = 1
                      AND NOT EXISTS (
                          SELECT 1 FROM VW_ALL_PLAN_ELEMENTS c
                          WHERE c.PARENT_ID = e.ID
                            AND c.PLAN_ORDER = e.PLAN_ORDER
                      )
                    ORDER BY e.PLAN_ORDER, e.CODE";

                using (SqlCommand cmd = new SqlCommand(sql, conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        var d = new Dictionary<string, object>();
                        d["ID"]          = r["ID"].ToString();
                        d["CODE"]        = r["CODE"].ToString();
                        d["LIBELLE"]     = r["LIBELLE"].ToString();
                        d["NIVEAU"]      = Convert.ToInt32(r["NIVEAU"]);
                        d["PLAN_ORDER"]  = Convert.ToInt32(r["PLAN_ORDER"]);
                        d["PLAN_CODE"]   = r["PLAN_CODE"] == DBNull.Value ? "" : r["PLAN_CODE"].ToString();
                        d["PLAN_NOM"]    = r["PLAN_NOM"] == DBNull.Value ? "" : r["PLAN_NOM"].ToString();
                        comptes.Add(d);
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = true,
                comptes = comptes
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

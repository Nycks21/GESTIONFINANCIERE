<%@ WebHandler Language="C#" Class="GetPlansComptables" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetPlansComptables : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        try
        {
            if (!AuthHelper.RequireApiPermission(ctx, "generale"))
            {
                ctx.Response.StatusCode = 403;
                ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
                return;
            }
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(JsonError("Erreur permission : " + ex.Message));
            return;
        }

        try
        {
            string connStr = AuthHelper.ConnectionString;
            var plans = new List<Dictionary<string, object>>();
            var types = new List<Dictionary<string, object>>();

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                // ─── Plans depuis VW_PLAN_HEADERS + comptage par PLANx ───
                // On compte les éléments via la vue UNION pour chaque slot
                string sql = @"
                    SELECT
                        h.ORDRE,
                        h.CODE,
                        h.NOM,
                        h.DESCRIPTION,
                        h.NIVEAU,
                        h.PLAN_TYPE_CODE,
                        pt.NOM AS TYPE_NOM,
                        h.EST_PRINCIPAL,
                        h.ACTIVE,
                        ISNULL((
                            SELECT COUNT(*)
                            FROM VW_ALL_PLAN_ELEMENTS e
                            WHERE e.PLAN_ORDER = h.ORDRE
                        ), 0) AS ELEMENT_COUNT
                    FROM FPLAN_HEADER h
                    LEFT JOIN FPLAN_TYPE pt ON pt.CODE = h.PLAN_TYPE_CODE
                    ORDER BY h.ORDRE";

                using (SqlCommand cmd = new SqlCommand(sql, conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        var d = new Dictionary<string, object>();
                        d["ORDRE"]           = Convert.ToInt32(r["ORDRE"]);
                        d["CODE"]            = r["CODE"] == DBNull.Value ? "" : r["CODE"].ToString();
                        d["NOM"]             = r["NOM"] == DBNull.Value ? "" : r["NOM"].ToString();
                        d["DESCRIPTION"]     = r["DESCRIPTION"] == DBNull.Value ? "" : r["DESCRIPTION"].ToString();
                        d["NIVEAU"]          = Convert.ToInt32(r["NIVEAU"]);
                        d["PLAN_TYPE_CODE"]  = r["PLAN_TYPE_CODE"] == DBNull.Value ? "" : r["PLAN_TYPE_CODE"].ToString();
                        d["TYPE_NOM"]        = r["TYPE_NOM"] == DBNull.Value ? "" : r["TYPE_NOM"].ToString();
                        d["EST_PRINCIPAL"]   = Convert.ToBoolean(r["EST_PRINCIPAL"]);
                        d["ACTIVE"]          = Convert.ToBoolean(r["ACTIVE"]);
                        d["ELEMENT_COUNT"]   = Convert.ToInt32(r["ELEMENT_COUNT"]);
                        plans.Add(d);
                    }
                }

                // ─── Types de plans pour dropdown ───
                string sqlTypes = @"
                    SELECT CODE, NOM
                    FROM FPLAN_TYPE
                    WHERE ACTIVE = 1
                    ORDER BY ORDRE, NOM";
                using (SqlCommand cmd = new SqlCommand(sqlTypes, conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        var d = new Dictionary<string, object>();
                        d["CODE"] = r["CODE"].ToString();
                        d["NOM"]  = r["NOM"].ToString();
                        types.Add(d);
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = true,
                plans = plans,
                types = types
            }));
        }
        catch (SqlException sqlEx)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(JsonError("SQL Error " + sqlEx.Number + " : " + sqlEx.Message));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(JsonError(ex.Message));
        }
    }

    private string JsonError(string msg)
    {
        return new JavaScriptSerializer().Serialize(new
        { success = false, message = msg ?? "Erreur inconnue" });
    }

    public bool IsReusable { get { return false; } }
}

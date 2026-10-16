<%@ WebHandler Language="C#" Class="GetMarcheLookups" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetMarcheLookups : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireApiPermission(ctx, "marche"))
        { ctx.Response.StatusCode = 403; ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}"); return; }

        try
        {
            string connStr = AuthHelper.ConnectionString;
            var sites         = new List<Dictionary<string, object>>();
            var fournisseurs  = new List<Dictionary<string, object>>();
            var articles      = new List<Dictionary<string, object>>();
            var monnaies      = new List<Dictionary<string, object>>();
            var plansActifs   = new List<Dictionary<string, object>>();

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                // ─── Sites ───
                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT ID, CODE, NOM FROM FSITE
                    WHERE ACTIVE = 1 AND DELETION_AT IS NULL
                    ORDER BY CODE", conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                        sites.Add(Row3(r, "ID", "CODE", "NOM"));
                }

                // ─── Fournisseurs : comptes collectifs de PLAN1 ───
                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT ID, CODE, LIBELLE AS NOM
                    FROM dbo.PLAN1
                    WHERE ACTIVE = 1
                      AND DELETION_AT IS NULL
                      AND CODE LIKE '4%'
                    ORDER BY CODE", conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                        fournisseurs.Add(Row3(r, "ID", "CODE", "NOM"));
                }

                // ─── Articles ───
                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT ID, CODE, NOM FROM MARTICLE
                    WHERE ACTIVE = 1 AND DELETION_AT IS NULL
                    ORDER BY CODE", conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                        articles.Add(Row3(r, "ID", "CODE", "NOM"));
                }

                // ─── Monnaies ───
                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT ID, CODE, NOM, EST_REFERENCE FROM FMONNAIE
                    WHERE ACTIVE = 1 AND DELETION_AT IS NULL
                    ORDER BY EST_REFERENCE DESC, CODE", conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        var d = Row3(r, "ID", "CODE", "NOM");
                        d["EST_REFERENCE"] = Convert.ToBoolean(r["EST_REFERENCE"]);
                        monnaies.Add(d);
                    }
                }

                // ─── Plans actifs ───
                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT h.ORDRE, h.CODE, h.NOM, h.PLAN_TYPE_CODE
                    FROM FPLAN_HEADER h
                    WHERE h.ACTIVE = 1
                    ORDER BY h.ORDRE", conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        var d = new Dictionary<string, object>();
                        d["ORDRE"]          = Convert.ToInt32(r["ORDRE"]);
                        d["CODE"]           = r["CODE"]           == DBNull.Value ? "" : r["CODE"].ToString();
                        d["NOM"]            = r["NOM"]            == DBNull.Value ? "" : r["NOM"].ToString();
                        d["PLAN_TYPE_CODE"] = r["PLAN_TYPE_CODE"] == DBNull.Value ? "" : r["PLAN_TYPE_CODE"].ToString();
                        plansActifs.Add(d);
                    }
                }

            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success      = true,
                sites        = sites,
                fournisseurs = fournisseurs,
                articles     = articles,
                monnaies     = monnaies,
                plansActifs  = plansActifs
            }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            { success = false, message = ex.Message }));
        }
    }

    private static Dictionary<string, object> Row3(SqlDataReader r, string idCol, string codeCol, string nomCol)
    {
        var d = new Dictionary<string, object>();
        d["ID"]   = r[idCol]   == DBNull.Value ? "" : r[idCol].ToString();
        d["CODE"] = r[codeCol] == DBNull.Value ? "" : r[codeCol].ToString();
        d["NOM"]  = r[nomCol]  == DBNull.Value ? "" : r[nomCol].ToString();
        return d;
    }

    public bool IsReusable { get { return false; } }
}

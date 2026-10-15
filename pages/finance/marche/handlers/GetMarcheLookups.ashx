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

                // Sites
                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT ID, CODE, NOM FROM FSITE
                    WHERE ACTIVE = 1 AND DELETION_AT IS NULL
                    ORDER BY CODE", conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        var d = new Dictionary<string, object>();
                        d["ID"] = r["ID"].ToString();
                        d["CODE"] = r["CODE"].ToString();
                        d["NOM"] = r["NOM"].ToString();
                        sites.Add(d);
                    }
                }

                // Fournisseurs
                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT ID, CODE, NOM FROM SFOURNISSEUR
                    WHERE ACTIVE = 1 AND DELETION_AT IS NULL
                    ORDER BY CODE", conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        var d = new Dictionary<string, object>();
                        d["ID"] = r["ID"].ToString();
                        d["CODE"] = r["CODE"].ToString();
                        d["NOM"] = r["NOM"].ToString();
                        fournisseurs.Add(d);
                    }
                }

                // Articles
                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT ID, CODE, NOM FROM MARTICLE
                    WHERE ACTIVE = 1 AND DELETION_AT IS NULL
                    ORDER BY CODE", conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        var d = new Dictionary<string, object>();
                        d["ID"] = r["ID"].ToString();
                        d["CODE"] = r["CODE"].ToString();
                        d["NOM"] = r["NOM"].ToString();
                        articles.Add(d);
                    }
                }

                // Monnaies
                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT ID, CODE, NOM, EST_REFERENCE FROM FMONNAIE
                    WHERE ACTIVE = 1 AND DELETION_AT IS NULL
                    ORDER BY EST_REFERENCE DESC, CODE", conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        var d = new Dictionary<string, object>();
                        d["ID"] = r["ID"].ToString();
                        d["CODE"] = r["CODE"].ToString();
                        d["NOM"] = r["NOM"].ToString();
                        d["EST_REFERENCE"] = Convert.ToBoolean(r["EST_REFERENCE"]);
                        monnaies.Add(d);
                    }
                }

                // Plans actifs
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
                        d["ORDRE"] = Convert.ToInt32(r["ORDRE"]);
                        d["CODE"] = r["CODE"] == DBNull.Value ? "" : r["CODE"].ToString();
                        d["NOM"] = r["NOM"] == DBNull.Value ? "" : r["NOM"].ToString();
                        d["PLAN_TYPE_CODE"] = r["PLAN_TYPE_CODE"] == DBNull.Value ? "" : r["PLAN_TYPE_CODE"].ToString();
                        plansActifs.Add(d);
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = true,
                sites = sites,
                fournisseurs = fournisseurs,
                articles = articles,
                monnaies = monnaies,
                plansActifs = plansActifs
            }));
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

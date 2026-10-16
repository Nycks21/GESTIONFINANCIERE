<%@ WebHandler Language="C#" Class="GetComptesByPlan" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetComptesByPlan : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireApiPermission(ctx, "saisie"))
        {
            ctx.Response.StatusCode = 403;
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            int ordre;
            if (!int.TryParse(ctx.Request.QueryString["planOrder"], out ordre) || ordre < 1 || ordre > 10)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"planOrder invalide.\"}");
                return;
            }

            string onlyAux = (ctx.Request.QueryString["onlyAuxiliaire"] ?? "").Trim();

            // Sécurité : valider le nom de table (1..10) → évite toute injection
            string tableName = "PLAN" + ordre;

            string connStr = AuthHelper.ConnectionString;
            var comptes = new List<Dictionary<string, object>>();

            // ✅ Requête corrigée : on récupère les comptes FEUILLES
            //    (pas d'enfants actifs) → ce sont ceux saisissables
            string sql = @"
                SELECT p.ID, p.CODE, p.LIBELLE, p.NIVEAU, p.TYPE_ELEMENT, p.EST_AUXILIAIRE
                  FROM " + tableName + @" p
                 WHERE p.ACTIVE = 1
                   AND p.DELETION_AT IS NULL
                   AND NOT EXISTS (
                        SELECT 1 FROM " + tableName + @" c
                         WHERE c.PARENT_ID = p.ID
                           AND c.DELETION_AT IS NULL
                           AND c.ACTIVE = 1
                   )";

            if (onlyAux == "1")
                sql += " AND p.EST_AUXILIAIRE = 1";

            sql += " ORDER BY p.CODE";

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        var d = new Dictionary<string, object>();
                        d["ID"]             = r["ID"].ToString();
                        d["CODE"]           = r["CODE"].ToString();
                        d["LIBELLE"]        = r["LIBELLE"].ToString();
                        d["NIVEAU"]         = Convert.ToInt32(r["NIVEAU"]);
                        d["TYPE_ELEMENT"]   = r["TYPE_ELEMENT"].ToString();
                        d["EST_AUXILIAIRE"] = Convert.ToBoolean(r["EST_AUXILIAIRE"]);
                        d["PLAN_ORDER"]     = ordre;
                        comptes.Add(d);
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            { success = true, comptes = comptes }));
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

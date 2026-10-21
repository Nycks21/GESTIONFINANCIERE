<%@ WebHandler Language="C#" Class="GetMarche" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

/// <summary>
/// Lookup simple des marchés actifs pour la page SAISIE.
/// Retourne ID, NUMERO, DESCRIPTION, STATUT, FOURNISSEUR_NOM…
/// </summary>
public class GetMarche : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json; charset=utf-8";
        ctx.Response.Charset = "utf-8";
        ctx.Response.ContentEncoding = System.Text.Encoding.UTF8;
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireApiPermission(ctx, "saisie"))
        {
            ctx.Response.StatusCode = 403;
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            string connStr = AuthHelper.ConnectionString;
            var marches = new List<Dictionary<string, object>>();

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT
                        ID, NUMERO, DESCRIPTION, STATUT, TYPE_MARCHE,
                        DATE_SIGNATURE, FOURNISSEUR_NOM
                    FROM FMARCHE
                    WHERE DELETION_AT IS NULL
                      AND STATUT <> 3                  -- 3 = ANNULÉ
                    ORDER BY DATE_SIGNATURE DESC, NUMERO DESC", conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        var d = new Dictionary<string, object>();
                        d["ID"]              = r["ID"].ToString();
                        d["NUMERO"]          = r["NUMERO"].ToString();
                        d["DESCRIPTION"]     = r["DESCRIPTION"]     == DBNull.Value ? "" : r["DESCRIPTION"].ToString();
                        d["STATUT"]          = Convert.ToInt32(r["STATUT"]);
                        d["TYPE_MARCHE"]     = r["TYPE_MARCHE"]     == DBNull.Value ? "" : r["TYPE_MARCHE"].ToString();
                        d["DATE_SIGNATURE"]  = r["DATE_SIGNATURE"]  == DBNull.Value ? "" : Convert.ToDateTime(r["DATE_SIGNATURE"]).ToString("yyyy-MM-dd");
                        d["FOURNISSEUR_NOM"] = r["FOURNISSEUR_NOM"] == DBNull.Value ? "" : r["FOURNISSEUR_NOM"].ToString();
                        marches.Add(d);
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            { success = true, marches = marches }));
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

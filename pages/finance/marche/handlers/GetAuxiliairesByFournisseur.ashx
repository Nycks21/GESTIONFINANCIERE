<%@ WebHandler Language="C#" Class="GetAuxiliairesByFournisseur" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

/// <summary>
/// Retourne UNIQUEMENT les auxiliaires (FTIERS) rattachés au compte collectif
/// du compte collectif (PLAN1) sélectionné.
///
/// Règle : FTIERS.PLAN_ELEMENT_ID == PLAN1.ID
/// Aucun fournisseur → liste vide (jamais de fallback).
/// </summary>
public class GetAuxiliairesByFournisseur : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset     = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireApiPermission(ctx, "marche"))
        {
            ctx.Response.StatusCode = 403;
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            string fourIdRaw = (ctx.Request.QueryString["fournisseurId"] ?? "").Trim();

            // ⭐ Aucun fournisseur → liste vide
            if (string.IsNullOrEmpty(fourIdRaw))
            {
                ctx.Response.Write(new JavaScriptSerializer().Serialize(new
                { success = true, auxiliaires = new List<object>() }));
                return;
            }

            Guid fourId;
            if (!Guid.TryParse(fourIdRaw, out fourId))
            {
                ctx.Response.StatusCode = 400;
                ctx.Response.Write("{\"success\":false,\"message\":\"fournisseurId invalide.\"}");
                return;
            }

            var auxiliaires = new List<Dictionary<string, object>>();
            string connStr = AuthHelper.ConnectionString;

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                // FTIERS.PLAN_ELEMENT_ID référence le compte collectif PLAN1.ID.
                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT t.ID, t.CODE, t.NOM, t.TYPE_TIERS,
                           t.PLAN_ELEMENT_ID, t.PLAN_ORDER
                    FROM dbo.FTIERS t
                    INNER JOIN dbo.PLAN1 p ON p.ID = t.PLAN_ELEMENT_ID
                    WHERE p.ID = @fourId
                      AND p.CODE LIKE '4%'
                      AND p.ACTIVE = 1
                      AND p.DELETION_AT IS NULL
                      AND t.ACTIVE = 1
                      AND t.DELETION_AT IS NULL
                    ORDER BY t.CODE", conn))
                {
                    cmd.Parameters.AddWithValue("@fourId", fourId);

                    using (SqlDataReader r = cmd.ExecuteReader())
                    {
                        while (r.Read())
                        {
                            var d = new Dictionary<string, object>();
                            d["ID"]              = r["ID"].ToString();
                            d["CODE"]            = r["CODE"].ToString();
                            d["NOM"]             = r["NOM"].ToString();
                            d["TYPE_TIERS"]      = r["TYPE_TIERS"]      == DBNull.Value ? "" : r["TYPE_TIERS"].ToString();
                            d["PLAN_ELEMENT_ID"] = r["PLAN_ELEMENT_ID"] == DBNull.Value ? "" : r["PLAN_ELEMENT_ID"].ToString();
                            d["PLAN_ORDER"]      = r["PLAN_ORDER"]      == DBNull.Value ? (object)null : Convert.ToInt32(r["PLAN_ORDER"]);
                            auxiliaires.Add(d);
                        }
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            { success = true, auxiliaires = auxiliaires }));
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

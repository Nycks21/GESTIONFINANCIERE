<%@ WebHandler Language="C#" Class="GetMarcheDetail" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetMarcheDetail : IHttpHandler, IRequiresSessionState
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
            string id = (ctx.Request.QueryString["id"] ?? "").Trim();
            Guid tmp;
            if (string.IsNullOrEmpty(id) || !Guid.TryParse(id, out tmp))
            { ctx.Response.Write("{\"success\":false,\"message\":\"ID invalide.\"}"); return; }

            string connStr = AuthHelper.ConnectionString;
            Dictionary<string, object> marche = null;
            var lignes = new List<Dictionary<string, object>>();

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                // EN-TÊTE
                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT ID, SITE_ID, NUMERO, DESCRIPTION, COURS_DEVISE,
                           TYPE_MARCHE, MODE_PASSATION, STATUT,
                           DATE_LANCEMENT, DATE_OUVERTURE_PLIS, DATE_ATTRIBUTION,
                           DATE_SIGNATURE, DATE_DEBUT, DATE_FIN, DELAI_EXECUTION_JOURS,
                           FOURNISSEUR_ID, FOURNISSEUR_NOM,
                           MONTANT_LOC_HT, MONTANT_LOC_TVA, MONTANT_LOC_TTC,
                           MONTANT_DEV_HT, MONTANT_DEV_TVA, MONTANT_DEV_TTC
                    FROM FMARCHE WHERE ID = @id AND DELETION_AT IS NULL", conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    using (SqlDataReader r = cmd.ExecuteReader())
                    {
                        if (r.Read())
                        {
                            marche = new Dictionary<string, object>();
                            marche["ID"] = r["ID"].ToString();
                            marche["SITE_ID"] = r["SITE_ID"] == DBNull.Value ? null : r["SITE_ID"].ToString();
                            marche["NUMERO"] = r["NUMERO"].ToString();
                            marche["DESCRIPTION"] = r["DESCRIPTION"] == DBNull.Value ? "" : r["DESCRIPTION"].ToString();
                            marche["COURS_DEVISE"] = r["COURS_DEVISE"] == DBNull.Value ? 0m : Convert.ToDecimal(r["COURS_DEVISE"]);
                            marche["TYPE_MARCHE"] = r["TYPE_MARCHE"].ToString();
                            marche["MODE_PASSATION"] = r["MODE_PASSATION"].ToString();
                            marche["STATUT"] = r["STATUT"].ToString();
                            marche["DATE_LANCEMENT"] = r["DATE_LANCEMENT"] == DBNull.Value ? "" : Convert.ToDateTime(r["DATE_LANCEMENT"]).ToString("yyyy-MM-dd");
                            marche["DATE_OUVERTURE_PLIS"] = r["DATE_OUVERTURE_PLIS"] == DBNull.Value ? "" : Convert.ToDateTime(r["DATE_OUVERTURE_PLIS"]).ToString("yyyy-MM-dd");
                            marche["DATE_ATTRIBUTION"] = r["DATE_ATTRIBUTION"] == DBNull.Value ? "" : Convert.ToDateTime(r["DATE_ATTRIBUTION"]).ToString("yyyy-MM-dd");
                            marche["DATE_SIGNATURE"] = r["DATE_SIGNATURE"] == DBNull.Value ? "" : Convert.ToDateTime(r["DATE_SIGNATURE"]).ToString("yyyy-MM-dd");
                            marche["DATE_DEBUT"] = r["DATE_DEBUT"] == DBNull.Value ? "" : Convert.ToDateTime(r["DATE_DEBUT"]).ToString("yyyy-MM-dd");
                            marche["DATE_FIN"] = r["DATE_FIN"] == DBNull.Value ? "" : Convert.ToDateTime(r["DATE_FIN"]).ToString("yyyy-MM-dd");
                            marche["DELAI_EXECUTION_JOURS"] = r["DELAI_EXECUTION_JOURS"] == DBNull.Value ? (object)null : Convert.ToInt32(r["DELAI_EXECUTION_JOURS"]);
                            marche["FOURNISSEUR_ID"] = r["FOURNISSEUR_ID"] == DBNull.Value ? null : r["FOURNISSEUR_ID"].ToString();
                            marche["FOURNISSEUR_NOM"] = r["FOURNISSEUR_NOM"] == DBNull.Value ? "" : r["FOURNISSEUR_NOM"].ToString();
                            marche["MONTANT_LOC_HT"] = Convert.ToDecimal(r["MONTANT_LOC_HT"]);
                            marche["MONTANT_LOC_TVA"] = Convert.ToDecimal(r["MONTANT_LOC_TVA"]);
                            marche["MONTANT_LOC_TTC"] = Convert.ToDecimal(r["MONTANT_LOC_TTC"]);
                            marche["MONTANT_DEV_HT"] = Convert.ToDecimal(r["MONTANT_DEV_HT"]);
                            marche["MONTANT_DEV_TVA"] = Convert.ToDecimal(r["MONTANT_DEV_TVA"]);
                            marche["MONTANT_DEV_TTC"] = Convert.ToDecimal(r["MONTANT_DEV_TTC"]);
                        }
                    }
                }

                if (marche == null)
                { ctx.Response.Write("{\"success\":false,\"message\":\"Marché introuvable.\"}"); return; }

                // LIGNES
                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT ID, ORDRE, ARTICLE_ID, DESIGNATION, REFERENCE_LIGNE,
                           EXERCICE_ID, DESCRIPTION, TAXE,
                           MONTANT_LOC_HT, MONTANT_LOC_TVA, MONTANT_LOC_TTC,
                           MONTANT_RAP_HT, MONTANT_RAP_TVA, MONTANT_RAP_TTC,
                           PLAN1, PLAN2, PLAN3, PLAN4, PLAN5,
                           PLAN6, PLAN7, PLAN8, PLAN9, PLAN10,
                           SOURCE_FINANCEMENT, OBSERVATIONS
                    FROM FMARCHE_LIGNE
                    WHERE MARCHE_ID = @id AND DELETION_AT IS NULL
                    ORDER BY ORDRE", conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    using (SqlDataReader r = cmd.ExecuteReader())
                    {
                        while (r.Read())
                        {
                            var l = new Dictionary<string, object>();
                            l["ID"] = r["ID"].ToString();
                            l["ORDRE"] = Convert.ToInt32(r["ORDRE"]);
                            l["ARTICLE_ID"] = r["ARTICLE_ID"] == DBNull.Value ? null : r["ARTICLE_ID"].ToString();
                            l["DESIGNATION"] = r["DESIGNATION"].ToString();
                            l["REFERENCE_LIGNE"] = r["REFERENCE_LIGNE"] == DBNull.Value ? "" : r["REFERENCE_LIGNE"].ToString();
                            l["EXERCICE_ID"] = r["EXERCICE_ID"].ToString();
                            l["DESCRIPTION"] = r["DESCRIPTION"] == DBNull.Value ? "" : r["DESCRIPTION"].ToString();
                            l["TAXE"] = Convert.ToDecimal(r["TAXE"]);
                            l["MONTANT_LOC_HT"] = Convert.ToDecimal(r["MONTANT_LOC_HT"]);
                            l["MONTANT_LOC_TVA"] = Convert.ToDecimal(r["MONTANT_LOC_TVA"]);
                            l["MONTANT_LOC_TTC"] = Convert.ToDecimal(r["MONTANT_LOC_TTC"]);
                            l["MONTANT_RAP_HT"] = Convert.ToDecimal(r["MONTANT_RAP_HT"]);
                            l["MONTANT_RAP_TVA"] = Convert.ToDecimal(r["MONTANT_RAP_TVA"]);
                            l["MONTANT_RAP_TTC"] = Convert.ToDecimal(r["MONTANT_RAP_TTC"]);
                            l["PLAN1"] = r["PLAN1"] == DBNull.Value ? null : r["PLAN1"].ToString();
                            l["PLAN2"] = r["PLAN2"] == DBNull.Value ? null : r["PLAN2"].ToString();
                            l["PLAN3"] = r["PLAN3"] == DBNull.Value ? null : r["PLAN3"].ToString();
                            l["PLAN4"] = r["PLAN4"] == DBNull.Value ? null : r["PLAN4"].ToString();
                            l["PLAN5"] = r["PLAN5"] == DBNull.Value ? null : r["PLAN5"].ToString();
                            l["PLAN6"] = r["PLAN6"] == DBNull.Value ? null : r["PLAN6"].ToString();
                            l["PLAN7"] = r["PLAN7"] == DBNull.Value ? null : r["PLAN7"].ToString();
                            l["PLAN8"] = r["PLAN8"] == DBNull.Value ? null : r["PLAN8"].ToString();
                            l["PLAN9"] = r["PLAN9"] == DBNull.Value ? null : r["PLAN9"].ToString();
                            l["PLAN10"] = r["PLAN10"] == DBNull.Value ? null : r["PLAN10"].ToString();
                            l["SOURCE_FINANCEMENT"] = r["SOURCE_FINANCEMENT"] == DBNull.Value ? "" : r["SOURCE_FINANCEMENT"].ToString();
                            l["OBSERVATIONS"] = r["OBSERVATIONS"] == DBNull.Value ? "" : r["OBSERVATIONS"].ToString();
                            lignes.Add(l);
                        }
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            { success = true, marche = marche, lignes = lignes }));
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

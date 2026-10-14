<%@ WebHandler Language="C#" Class="GetEcritureDetail" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetEcritureDetail : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireApiPermission(ctx, "saisie"))
        { ctx.Response.StatusCode = 403; ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}"); return; }

        try
        {
            string id = (ctx.Request.QueryString["id"] ?? "").Trim();
            Guid tmp;
            if (string.IsNullOrEmpty(id) || !Guid.TryParse(id, out tmp))
            { ctx.Response.Write("{\"success\":false,\"message\":\"ID invalide.\"}"); return; }

            string connStr = AuthHelper.ConnectionString;
            Dictionary<string, object> ecriture = null;
            var lignes = new List<Dictionary<string, object>>();

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                // ─── EN-TÊTE FECRITURE ───
                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT ID, EXERCICE_ID, PERIODE_ID, JOURNAL_ID, SITE_ID, MONNAIE_ID,
                           NUMERO, DATE_COMPTABLE, DATE_PIECE, REFERENCE, LIBELLE,
                           TOTAL_DEBIT, TOTAL_CREDIT, STATUT
                    FROM FECRITURE WHERE ID = @id", conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    using (SqlDataReader r = cmd.ExecuteReader())
                    {
                        if (r.Read())
                        {
                            ecriture = new Dictionary<string, object>();
                            ecriture["ID"]              = r["ID"].ToString();
                            ecriture["EXERCICE_ID"]     = r["EXERCICE_ID"].ToString();
                            ecriture["PERIODE_ID"]      = r["PERIODE_ID"].ToString();
                            ecriture["JOURNAL_ID"]      = r["JOURNAL_ID"].ToString();
                            ecriture["SITE_ID"]         = r["SITE_ID"] == DBNull.Value ? null : r["SITE_ID"].ToString();
                            ecriture["MONNAIE_ID"]      = r["MONNAIE_ID"].ToString();
                            ecriture["NUMERO"]          = r["NUMERO"].ToString();
                            ecriture["DATE_COMPTABLE"]  = Convert.ToDateTime(r["DATE_COMPTABLE"]).ToString("yyyy-MM-dd");
                            ecriture["DATE_PIECE"]      = r["DATE_PIECE"] == DBNull.Value ? "" : Convert.ToDateTime(r["DATE_PIECE"]).ToString("yyyy-MM-dd");
                            ecriture["REFERENCE"]       = r["REFERENCE"] == DBNull.Value ? "" : r["REFERENCE"].ToString();
                            ecriture["LIBELLE"]         = r["LIBELLE"].ToString();
                            ecriture["TOTAL_DEBIT"]     = r["TOTAL_DEBIT"]  == DBNull.Value ? 0m : Convert.ToDecimal(r["TOTAL_DEBIT"]);
                            ecriture["TOTAL_CREDIT"]    = r["TOTAL_CREDIT"] == DBNull.Value ? 0m : Convert.ToDecimal(r["TOTAL_CREDIT"]);
                            ecriture["STATUT"]          = r["STATUT"].ToString();
                        }
                    }
                }

                if (ecriture == null)
                { ctx.Response.Write("{\"success\":false,\"message\":\"Écriture introuvable.\"}"); return; }

                // ─── LIGNES FECRITURE_LIGNE ───
                //   ⭐ Lecture de SENS + MONTANT → restitution aussi en DEBIT/CREDIT
                //      pour compatibilité totale avec le frontend existant.
                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT ID, ORDRE, COMPTE_ID, COMPTE_PLAN_ORDER, TIERS_ID, AUXILIAIRE,
                           LIBELLE, SENS, MONTANT, MONTANT_DEVISE, COURS_DEVISE,
                           OPERATION_PUBLIQUE_ID, OP_PLAN_ORDER,
                           PLAN1, PLAN2, PLAN3, PLAN4, PLAN5,
                           PLAN6, PLAN7, PLAN8, PLAN9, PLAN10,
                           LETTRABLE, SOURCE_FINANCEMENT
                    FROM FECRITURE_LIGNE
                    WHERE ECRITURE_ID = @id
                    ORDER BY ORDRE", conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    using (SqlDataReader r = cmd.ExecuteReader())
                    {
                        while (r.Read())
                        {
                            var l = new Dictionary<string, object>();
                            l["ID"]                    = r["ID"].ToString();
                            l["ORDRE"]                 = Convert.ToInt32(r["ORDRE"]);
                            l["COMPTE_ID"]             = r["COMPTE_ID"].ToString();
                            l["COMPTE_PLAN_ORDER"]     = r["COMPTE_PLAN_ORDER"] == DBNull.Value ? (object)null : Convert.ToInt32(r["COMPTE_PLAN_ORDER"]);
                            l["TIERS_ID"]              = r["TIERS_ID"] == DBNull.Value ? null : r["TIERS_ID"].ToString();
                            l["AUXILIAIRE"]            = r["AUXILIAIRE"] == DBNull.Value ? "" : r["AUXILIAIRE"].ToString();
                            l["LIBELLE"]               = r["LIBELLE"] == DBNull.Value ? "" : r["LIBELLE"].ToString();

                            // ⭐ SENS + MONTANT (nouveaux champs)
                            string sens = r["SENS"] == DBNull.Value ? null : r["SENS"].ToString();
                            decimal? montant = r["MONTANT"] == DBNull.Value ? (decimal?)null : Convert.ToDecimal(r["MONTANT"]);

                            l["SENS"]    = sens;
                            l["MONTANT"] = montant;

                            // ─── Compatibilité : DEBIT / CREDIT calculés ───
                            l["DEBIT"]  = (sens == "D" && montant.HasValue) ? (object)montant.Value : 0m;
                            l["CREDIT"] = (sens == "C" && montant.HasValue) ? (object)montant.Value : 0m;

                            l["MONTANT_DEVISE"]        = r["MONTANT_DEVISE"] == DBNull.Value ? (object)null : Convert.ToDecimal(r["MONTANT_DEVISE"]);
                            l["COURS_DEVISE"]          = r["COURS_DEVISE"]   == DBNull.Value ? (object)null : Convert.ToDecimal(r["COURS_DEVISE"]);
                            l["OPERATION_PUBLIQUE_ID"] = r["OPERATION_PUBLIQUE_ID"] == DBNull.Value ? null : r["OPERATION_PUBLIQUE_ID"].ToString();
                            l["OP_PLAN_ORDER"]         = r["OP_PLAN_ORDER"] == DBNull.Value ? (object)null : Convert.ToInt32(r["OP_PLAN_ORDER"]);
                            l["PLAN1"]                 = r["PLAN1"]  == DBNull.Value ? null : r["PLAN1"].ToString();
                            l["PLAN2"]                 = r["PLAN2"]  == DBNull.Value ? null : r["PLAN2"].ToString();
                            l["PLAN3"]                 = r["PLAN3"]  == DBNull.Value ? null : r["PLAN3"].ToString();
                            l["PLAN4"]                 = r["PLAN4"]  == DBNull.Value ? null : r["PLAN4"].ToString();
                            l["PLAN5"]                 = r["PLAN5"]  == DBNull.Value ? null : r["PLAN5"].ToString();
                            l["PLAN6"]                 = r["PLAN6"]  == DBNull.Value ? null : r["PLAN6"].ToString();
                            l["PLAN7"]                 = r["PLAN7"]  == DBNull.Value ? null : r["PLAN7"].ToString();
                            l["PLAN8"]                 = r["PLAN8"]  == DBNull.Value ? null : r["PLAN8"].ToString();
                            l["PLAN9"]                 = r["PLAN9"]  == DBNull.Value ? null : r["PLAN9"].ToString();
                            l["PLAN10"]                = r["PLAN10"] == DBNull.Value ? null : r["PLAN10"].ToString();
                            l["LETTRABLE"]             = r["LETTRABLE"] == DBNull.Value ? false : Convert.ToBoolean(r["LETTRABLE"]);
                            l["SOURCE_FINANCEMENT"]    = r["SOURCE_FINANCEMENT"] == DBNull.Value ? "" : r["SOURCE_FINANCEMENT"].ToString();

                            lignes.Add(l);
                        }
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            { success = true, ecriture = ecriture, lignes = lignes }));
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

<%@ WebHandler Language="C#" Class="GetSaisieLookups" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetSaisieLookups : IHttpHandler, IRequiresSessionState
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
            string connStr = AuthHelper.ConnectionString;

            var sites       = new List<Dictionary<string, object>>();
            var journaux    = new List<Dictionary<string, object>>();
            var exercices   = new List<Dictionary<string, object>>();
            var monnaies    = new List<Dictionary<string, object>>();
            var tiers       = new List<Dictionary<string, object>>();
            var sourcesFin  = new List<Dictionary<string, object>>();
            var modes       = new List<Dictionary<string, object>>();
            var plansActifs = new List<Dictionary<string, object>>();

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                // ─── Sites actifs (Centre de saisie) ───
                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT ID, CODE, NOM
                    FROM FSITE
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

                // ─── Journaux actifs ───
                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT ID, CODE, LIBELLE, TYPE_JOURNAL, CATEGORIE_JOURNAL,
                           COMPTE_BANQUE_ID, PLAN_ORDER
                    FROM FJOURNAL
                    WHERE ACTIVE = 1 AND DELETION_AT IS NULL
                    ORDER BY CODE", conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        var d = new Dictionary<string, object>();
                        d["ID"]                = r["ID"].ToString();
                        d["CODE"]              = r["CODE"].ToString();
                        d["LIBELLE"]           = r["LIBELLE"].ToString();
                        d["TYPE_JOURNAL"]      = r["TYPE_JOURNAL"].ToString();
                        d["CATEGORIE_JOURNAL"] = Convert.ToInt32(r["CATEGORIE_JOURNAL"]);
                        d["COMPTE_BANQUE_ID"]  = r["COMPTE_BANQUE_ID"] == DBNull.Value ? null : r["COMPTE_BANQUE_ID"].ToString();
                        d["PLAN_ORDER"]        = r["PLAN_ORDER"] == DBNull.Value ? (object)null : Convert.ToInt32(r["PLAN_ORDER"]);
                        journaux.Add(d);
                    }
                }

                // ─── Exercices OUVERT ───
                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT ID, CODE, LIBELLE, DATE_DEBUT, DATE_FIN, STATUT
                    FROM FEXERCICE
                    WHERE DELETION_AT IS NULL AND STATUT = 'OUVERT'
                    ORDER BY DATE_DEBUT DESC", conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        var d = new Dictionary<string, object>();
                        d["ID"]         = r["ID"].ToString();
                        d["CODE"]       = r["CODE"].ToString();
                        d["LIBELLE"]    = r["LIBELLE"].ToString();
                        d["DATE_DEBUT"] = Convert.ToDateTime(r["DATE_DEBUT"]).ToString("yyyy-MM-dd");
                        d["DATE_FIN"]   = Convert.ToDateTime(r["DATE_FIN"]).ToString("yyyy-MM-dd");
                        exercices.Add(d);
                    }
                }

                // ─── Monnaies actives ───
                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT ID, CODE, NOM, DECIMALES, EST_REFERENCE
                    FROM FMONNAIE
                    WHERE ACTIVE = 1 AND DELETION_AT IS NULL
                    ORDER BY EST_REFERENCE DESC, CODE", conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        var d = new Dictionary<string, object>();
                        d["ID"]            = r["ID"].ToString();
                        d["CODE"]          = r["CODE"].ToString();
                        d["NOM"]           = r["NOM"].ToString();
                        d["DECIMALES"]     = Convert.ToInt32(r["DECIMALES"]);
                        d["EST_REFERENCE"] = Convert.ToBoolean(r["EST_REFERENCE"]);
                        monnaies.Add(d);
                    }
                }

                // ─── Tiers actifs ───
                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT ID, CODE, NOM, TYPE_TIERS, PLAN_ELEMENT_ID, PLAN_ORDER
                    FROM FTIERS
                    WHERE ACTIVE = 1 AND DELETION_AT IS NULL
                    ORDER BY CODE", conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        var d = new Dictionary<string, object>();
                        d["ID"]              = r["ID"].ToString();
                        d["CODE"]            = r["CODE"].ToString();
                        d["NOM"]             = r["NOM"].ToString();
                        d["TYPE_TIERS"]      = r["TYPE_TIERS"].ToString();
                        d["PLAN_ELEMENT_ID"] = r["PLAN_ELEMENT_ID"] == DBNull.Value ? null : r["PLAN_ELEMENT_ID"].ToString();
                        d["PLAN_ORDER"]      = r["PLAN_ORDER"] == DBNull.Value ? (object)null : Convert.ToInt32(r["PLAN_ORDER"]);
                        tiers.Add(d);
                    }
                }

                // ─── Sources de financement ───
                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT p.CODE, p.LIBELLE, p.ORDRE
                    FROM FPARAMETRE p
                    INNER JOIN FPARAMETRE_SECTION s ON s.ID = p.SECTION_ID
                    WHERE s.CODE = 'SOURCES_FINANCEMENT'
                      AND p.ACTIVE = 1
                    ORDER BY p.ORDRE", conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        var d = new Dictionary<string, object>();
                        d["CODE"]    = r["CODE"].ToString();
                        d["LIBELLE"] = r["LIBELLE"] == DBNull.Value ? r["CODE"].ToString() : r["LIBELLE"].ToString();
                        sourcesFin.Add(d);
                    }
                }

                // ─── Modes de régularisation ───
                // Utilise la section 'MODES_REGULARISATION' si elle existe,
                // sinon fallback sur une liste standard.
                bool modesFound = false;
                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT p.CODE, p.LIBELLE, p.ORDRE
                    FROM FPARAMETRE p
                    INNER JOIN FPARAMETRE_SECTION s ON s.ID = p.SECTION_ID
                    WHERE s.CODE = 'MODES_REGULARISATION'
                      AND p.ACTIVE = 1
                    ORDER BY p.ORDRE", conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        modesFound = true;
                        var d = new Dictionary<string, object>();
                        d["CODE"]    = r["CODE"].ToString();
                        d["LIBELLE"] = r["LIBELLE"] == DBNull.Value ? r["CODE"].ToString() : r["LIBELLE"].ToString();
                        modes.Add(d);
                    }
                }

                if (!modesFound)
                {
                    // Fallback : liste standard (miroir de CK_FECL_MODE_REG)
                    var stdModes = new[]
                    {
                        new { Code = "VIREMENT",     Lib = "Virement" },
                        new { Code = "ESPECE",       Lib = "Espèce" },
                        new { Code = "CHEQUE",       Lib = "Chèque" },
                        new { Code = "MOBILE_MONEY", Lib = "Mobile Money" },
                        new { Code = "CARTE",        Lib = "Carte bancaire" },
                        new { Code = "AUTRE",        Lib = "Autre" }
                    };

                    foreach (var m in stdModes)
                    {
                        var d = new Dictionary<string, object>();
                        d["CODE"]    = m.Code;
                        d["LIBELLE"] = m.Lib;
                        modes.Add(d);
                    }
                }

                // ─── Plans actifs (analytique) ───
                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT h.ORDRE, h.CODE, h.NOM, h.NIVEAU, h.PLAN_TYPE_CODE,
                           pt.NOM AS TYPE_NOM
                    FROM FPLAN_HEADER h
                    LEFT JOIN FPLAN_TYPE pt ON pt.CODE = h.PLAN_TYPE_CODE
                    WHERE h.ACTIVE = 1
                    ORDER BY h.ORDRE", conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        var d = new Dictionary<string, object>();
                        d["ORDRE"]          = Convert.ToInt32(r["ORDRE"]);
                        d["CODE"]           = r["CODE"] == DBNull.Value ? "" : r["CODE"].ToString();
                        d["NOM"]            = r["NOM"] == DBNull.Value ? "" : r["NOM"].ToString();
                        d["NIVEAU"]         = Convert.ToInt32(r["NIVEAU"]);
                        d["PLAN_TYPE_CODE"] = r["PLAN_TYPE_CODE"] == DBNull.Value ? "" : r["PLAN_TYPE_CODE"].ToString();
                        d["TYPE_NOM"]       = r["TYPE_NOM"] == DBNull.Value ? "" : r["TYPE_NOM"].ToString();
                        plansActifs.Add(d);
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success            = true,
                sites              = sites,
                journaux           = journaux,
                exercices          = exercices,
                monnaies           = monnaies,
                tiers              = tiers,
                sourcesFinancement = sourcesFin,
                modes              = modes,
                plansActifs        = plansActifs
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

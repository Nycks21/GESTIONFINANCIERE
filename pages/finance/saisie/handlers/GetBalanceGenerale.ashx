<%@ WebHandler Language="C#" Class="GetBalanceGenerale" %>
using System;
using System.Collections.Generic;
using System.Data;              // ⭐ REQUIS pour SqlDbType
using System.Data.SqlClient;
using System.Linq;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetBalanceGenerale : IHttpHandler, IRequiresSessionState
{
    private static readonly DateTime SQL_MIN = new DateTime(1753, 1, 1);
    private static readonly DateTime SQL_MAX = new DateTime(9999, 12, 31);

    private static readonly string[] ALLOWED_STATUTS = new[]
    {
        "BROUILLON", "A_VALIDER", "VALIDEE", "COMPTABILISEE", "CORRIGEE", "ANNULEE"
    };

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
            // ─── Lecture des paramètres ───
            string exerciceId   = (ctx.Request.QueryString["exerciceId"]   ?? "").Trim();
            string dateDebutStr = (ctx.Request.QueryString["dateDebut"]    ?? "").Trim();
            string dateFinStr   = (ctx.Request.QueryString["dateFin"]      ?? "").Trim();
            string siteId       = (ctx.Request.QueryString["siteId"]       ?? "").Trim();
            string statutStr    = (ctx.Request.QueryString["statuts"]      ?? "VALIDEE,COMPTABILISEE").Trim();
            string compteDebut  = (ctx.Request.QueryString["compteDebut"]  ?? "").Trim();
            string compteFin    = (ctx.Request.QueryString["compteFin"]    ?? "").Trim();

            bool masquerSansMvt   = ctx.Request.QueryString["masquerSansMvt"]   == "1";
            bool masquerRubriques = ctx.Request.QueryString["masquerRubriques"] == "1";

            // ─── Validation exercice ───
            Guid exerciceGuid;
            if (!Guid.TryParse(exerciceId, out exerciceGuid))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Exercice requis.\"}");
                return;
            }

            // ─── Détection plage de dates (DATE_COMPTABLE) ───
            bool dateRangeApplied = !string.IsNullOrEmpty(dateDebutStr)
                                 || !string.IsNullOrEmpty(dateFinStr);

            DateTime dtDebut = SQL_MIN;
            DateTime dtFin   = SQL_MAX;
            DateTime parsed;

            if (!string.IsNullOrEmpty(dateDebutStr) && DateTime.TryParse(dateDebutStr, out parsed))
            {
                DateTime d = parsed.Date;
                if (d < SQL_MIN)      d = SQL_MIN;
                if (d > SQL_MAX.Date) d = SQL_MAX.Date;
                dtDebut = d;
            }

            if (!string.IsNullOrEmpty(dateFinStr) && DateTime.TryParse(dateFinStr, out parsed))
            {
                DateTime d = parsed.Date;
                if (d < SQL_MIN)      d = SQL_MIN;
                if (d > SQL_MAX.Date) d = SQL_MAX.Date;
                // Évite l'overflow si d == 9999-12-31
                dtFin = (d == SQL_MAX.Date)
                    ? SQL_MAX
                    : d.Date.AddHours(23).AddMinutes(59).AddSeconds(59);
            }

            // ─── Normalisation des statuts ───
            var statuts = statutStr.Split(',')
                .Select(s => s.Trim().ToUpperInvariant())
                .Where(s => ALLOWED_STATUTS.Contains(s))
                .ToList();
            if (statuts.Count == 0) statuts.Add("VALIDEE");

            string[] statutArr = statuts.Select((s, i) => "@st" + i).ToArray();
            string statutIn = string.Join(",", statutArr);

            string connStr = AuthHelper.ConnectionString;
            int planOrder = 1;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // ─── Détection du plan comptable actif ───
                using (var cmd = new SqlCommand(@"
                    SELECT TOP 1 ORDRE FROM FPLAN_HEADER
                    WHERE PLAN_TYPE_CODE = 'COMPTABLE' AND ACTIVE = 1
                    ORDER BY ORDRE", conn))
                {
                    object o = cmd.ExecuteScalar();
                    if (o != null && o != DBNull.Value) planOrder = Convert.ToInt32(o);
                }
                if (planOrder < 1 || planOrder > 10) planOrder = 1;
                string planTable = "PLAN" + planOrder;

                // ─── Paramètres SQL ───
                var parameters = new List<SqlParameter>();
                for (int i = 0; i < statuts.Count; i++)
                    parameters.Add(new SqlParameter("@st" + i, SqlDbType.VarChar, 25) { Value = statuts[i] });

                parameters.Add(new SqlParameter("@dateDebut",  SqlDbType.DateTime)         { Value = dtDebut });
                parameters.Add(new SqlParameter("@dateFin",    SqlDbType.DateTime)         { Value = dtFin });
                parameters.Add(new SqlParameter("@exerciceId", SqlDbType.UniqueIdentifier) { Value = exerciceGuid });
                parameters.Add(new SqlParameter("@planOrder",  SqlDbType.TinyInt)          { Value = (byte)planOrder });

                string whereExtra = "";
                Guid g;

                if (!string.IsNullOrEmpty(siteId) && Guid.TryParse(siteId, out g))
                {
                    whereExtra += " AND e.SITE_ID = @siteId ";
                    parameters.Add(new SqlParameter("@siteId", SqlDbType.UniqueIdentifier) { Value = g });
                }
                if (!string.IsNullOrEmpty(compteDebut))
                {
                    whereExtra += " AND p.CODE >= @compteDebut ";
                    parameters.Add(new SqlParameter("@compteDebut", SqlDbType.VarChar, 50) { Value = compteDebut });
                }
                if (!string.IsNullOrEmpty(compteFin))
                {
                    whereExtra += " AND p.CODE <= @compteFin ";
                    parameters.Add(new SqlParameter("@compteFin", SqlDbType.VarChar, 50) { Value = compteFin });
                }
                if (masquerRubriques)
                {
                    whereExtra += " AND p.TYPE_ELEMENT = 'DETAIL' ";
                }

                // ─── Requête principale (DATE_COMPTABLE pour toutes les bornes) ───
                string sql = @"
                    SELECT
                        p.CODE,
                        p.LIBELLE,
                        p.NIVEAU,
                        p.TYPE_ELEMENT,
                        ISNULL(SUM(CASE WHEN e.DATE_COMPTABLE < @dateDebut AND l.SENS = 'D'
                                        THEN l.MONTANT ELSE 0 END), 0) AS INIT_DEBIT,
                        ISNULL(SUM(CASE WHEN e.DATE_COMPTABLE < @dateDebut AND l.SENS = 'C'
                                        THEN l.MONTANT ELSE 0 END), 0) AS INIT_CREDIT,
                        ISNULL(SUM(CASE WHEN e.DATE_COMPTABLE BETWEEN @dateDebut AND @dateFin AND l.SENS = 'D'
                                        THEN l.MONTANT ELSE 0 END), 0) AS MVT_DEBIT,
                        ISNULL(SUM(CASE WHEN e.DATE_COMPTABLE BETWEEN @dateDebut AND @dateFin AND l.SENS = 'C'
                                        THEN l.MONTANT ELSE 0 END), 0) AS MVT_CREDIT
                    FROM FECRITURE_LIGNE l
                    INNER JOIN FECRITURE e ON e.ID = l.ECRITURE_ID
                    INNER JOIN dbo." + planTable + @" p ON p.ID = l.COMPTE_ID
                    WHERE e.EXERCICE_ID = @exerciceId
                      AND e.STATUT IN (" + statutIn + @")
                      AND COALESCE(l.COMPTE_PLAN_ORDER, @planOrder) = @planOrder
                      AND p.DELETION_AT IS NULL
                      AND p.ACTIVE = 1
                      " + whereExtra + @"
                    GROUP BY p.CODE, p.LIBELLE, p.NIVEAU, p.TYPE_ELEMENT
                    ORDER BY p.CODE";

                var lignes = new List<Dictionary<string, object>>();
                decimal tInitD = 0, tInitC = 0, tMvtD = 0, tMvtC = 0, tFinalD = 0, tFinalC = 0;

                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddRange(parameters.ToArray());

                    using (var r = cmd.ExecuteReader())
                    {
                        while (r.Read())
                        {
                            var d = new Dictionary<string, object>();
                            d["CODE"]         = r["CODE"].ToString();
                            d["LIBELLE"]      = r["LIBELLE"].ToString();
                            d["NIVEAU"]       = Convert.ToInt32(r["NIVEAU"]);
                            d["TYPE_ELEMENT"] = r["TYPE_ELEMENT"].ToString();

                            decimal initD = r["INIT_DEBIT"]  == DBNull.Value ? 0m : Convert.ToDecimal(r["INIT_DEBIT"]);
                            decimal initC = r["INIT_CREDIT"] == DBNull.Value ? 0m : Convert.ToDecimal(r["INIT_CREDIT"]);
                            decimal mvtD  = r["MVT_DEBIT"]   == DBNull.Value ? 0m : Convert.ToDecimal(r["MVT_DEBIT"]);
                            decimal mvtC  = r["MVT_CREDIT"]  == DBNull.Value ? 0m : Convert.ToDecimal(r["MVT_CREDIT"]);

                            decimal soldeInit  = initD - initC;
                            decimal soldeFinal = soldeInit + mvtD - mvtC;

                            decimal initDShown  = soldeInit  > 0 ? soldeInit  : 0;
                            decimal initCShown  = soldeInit  < 0 ? -soldeInit : 0;
                            decimal finalDShown = soldeFinal > 0 ? soldeFinal : 0;
                            decimal finalCShown = soldeFinal < 0 ? -soldeFinal: 0;

                            d["INIT_DEBIT"]         = initDShown;
                            d["INIT_CREDIT"]        = initCShown;
                            d["MVT_DEBIT"]          = mvtD;
                            d["MVT_CREDIT"]         = mvtC;
                            d["SOLDE_FINAL_DEBIT"]  = finalDShown;
                            d["SOLDE_FINAL_CREDIT"] = finalCShown;

                            tInitD  += initDShown;  tInitC  += initCShown;
                            tMvtD   += mvtD;        tMvtC   += mvtC;
                            tFinalD += finalDShown; tFinalC += finalCShown;

                            lignes.Add(d);
                        }
                    }
                }

                // ─── Masquage des comptes sans mouvement ───
                if (masquerSansMvt)
                {
                    if (dateRangeApplied)
                    {
                        // Plage Du/Au active → ne garder que les comptes ayant
                        // des MOUVEMENTS dans la période (DATE_COMPTABLE ∈ [du, au]).
                        lignes = lignes.Where(x =>
                            Convert.ToDecimal(x["MVT_DEBIT"])  != 0 ||
                            Convert.ToDecimal(x["MVT_CREDIT"]) != 0
                        ).ToList();
                    }
                    else
                    {
                        // Pas de plage → on garde aussi les comptes avec solde initial seul
                        lignes = lignes.Where(x =>
                            Convert.ToDecimal(x["INIT_DEBIT"])  != 0 ||
                            Convert.ToDecimal(x["INIT_CREDIT"]) != 0 ||
                            Convert.ToDecimal(x["MVT_DEBIT"])   != 0 ||
                            Convert.ToDecimal(x["MVT_CREDIT"])  != 0
                        ).ToList();
                    }
                }

                // ─── Réponse JSON ───
                var ser = new JavaScriptSerializer();
                ctx.Response.Write(ser.Serialize(new
                {
                    success = true,
                    lignes  = lignes,
                    totaux  = new
                    {
                        initDebit   = tInitD,
                        initCredit  = tInitC,
                        mvtDebit    = tMvtD,
                        mvtCredit   = tMvtC,
                        finalDebit  = tFinalD,
                        finalCredit = tFinalC,
                        soldeInit   = tInitD - tInitC,
                        soldeFinal  = tFinalD - tFinalC
                    },
                    planOrder        = planOrder,
                    dateRangeApplied = dateRangeApplied,
                    count            = lignes.Count
                }));
            }
        }
        catch (SqlException sqlEx)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = false,
                message = "SQL Error " + sqlEx.Number + " (Line " + sqlEx.LineNumber + ") : " + sqlEx.Message
            }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            string inner = ex.InnerException != null ? " | INNER: " + ex.InnerException.Message : "";
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = false,
                message = ex.Message + inner,
                type = ex.GetType().Name
            }));
        }
    }

    public bool IsReusable { get { return false; } }
}

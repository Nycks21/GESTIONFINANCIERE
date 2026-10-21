<%@ WebHandler Language="C#" Class="GetEcritures" %>
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

// ⚠️ C# 4 uniquement — NE PAS utiliser : out var, $"...", ?., nameof, Math.Clamp
public class GetEcritures : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json; charset=utf-8";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireApiPermission(ctx, "saisie"))
        { ctx.Response.StatusCode = 403; ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}"); return; }

        try
        {
            // ── Pagination ──
            int page = 1, pageSize = 10;
            int.TryParse(ctx.Request.QueryString["page"], out page);
            int.TryParse(ctx.Request.QueryString["pageSize"], out pageSize);
            if (page < 1) page = 1;
            if (pageSize <= 0 || pageSize > 200) pageSize = 10;

            // ── Filtres existants ──
            string search  = (ctx.Request.QueryString["search"]  ?? "").Trim();
            string journal = (ctx.Request.QueryString["journalId"] ?? "").Trim();
            string statut  = (ctx.Request.QueryString["statut"]  ?? "").Trim();

            // ── ⭐ Nouveaux filtres ──
            string exerciceId     = (ctx.Request.QueryString["exerciceId"]     ?? "").Trim();
            string dateDebut      = (ctx.Request.QueryString["dateDebut"]      ?? "").Trim();
            string dateFin        = (ctx.Request.QueryString["dateFin"]        ?? "").Trim();
            string datePieceDebut = (ctx.Request.QueryString["datePieceDebut"] ?? "").Trim();
            string datePieceFin   = (ctx.Request.QueryString["datePieceFin"]   ?? "").Trim();
            string numeroPiece    = (ctx.Request.QueryString["numeroPiece"]    ?? "").Trim();
            string compte         = (ctx.Request.QueryString["compte"]         ?? "").Trim();
            string tiers          = (ctx.Request.QueryString["tiers"]          ?? "").Trim();
            string marche         = (ctx.Request.QueryString["marche"]         ?? "").Trim();

            string connStr = AuthHelper.ConnectionString;
            var ecritures = new List<Dictionary<string, object>>();
            int total = 0;

            // ── Construction dynamique du WHERE ──
            string whereClause = " WHERE e.STATUT <> 'ANNULEE'";
            var parameters = new List<SqlParameter>();

            // ⭐ C# 4 : variables déclarées AVANT les TryParse
            Guid jGuid = Guid.Empty;
            Guid exGuid = Guid.Empty;
            DateTime dd  = DateTime.MinValue;
            DateTime df  = DateTime.MinValue;
            DateTime dpd = DateTime.MinValue;
            DateTime dpf = DateTime.MinValue;

            if (!string.IsNullOrEmpty(search))
            {
                whereClause += " AND (e.NUMERO LIKE @search OR e.LIBELLE LIKE @search OR e.REFERENCE LIKE @search)";
                parameters.Add(new SqlParameter("@search", "%" + search + "%"));
            }

            if (!string.IsNullOrEmpty(journal) && Guid.TryParse(journal, out jGuid))
            {
                whereClause += " AND e.JOURNAL_ID = @journal";
                parameters.Add(new SqlParameter("@journal", jGuid));
            }

            if (!string.IsNullOrEmpty(statut))
            {
                whereClause += " AND e.STATUT = @statut";
                parameters.Add(new SqlParameter("@statut", statut));
            }

            // ⭐ Exercice
            if (!string.IsNullOrEmpty(exerciceId) && Guid.TryParse(exerciceId, out exGuid))
            {
                whereClause += " AND e.EXERCICE_ID = @exerciceId";
                parameters.Add(new SqlParameter("@exerciceId", exGuid));
            }

            // ⭐ Date comptable du/au
            if (!string.IsNullOrEmpty(dateDebut) && DateTime.TryParse(dateDebut, out dd))
            {
                whereClause += " AND e.DATE_COMPTABLE >= @dateDebut";
                parameters.Add(new SqlParameter("@dateDebut", dd.Date));
            }
            if (!string.IsNullOrEmpty(dateFin) && DateTime.TryParse(dateFin, out df))
            {
                whereClause += " AND e.DATE_COMPTABLE <= @dateFin";
                parameters.Add(new SqlParameter("@dateFin", df.Date.AddDays(1)));
            }

            // ⭐ Date pièce du/au
            if (!string.IsNullOrEmpty(datePieceDebut) && DateTime.TryParse(datePieceDebut, out dpd))
            {
                whereClause += " AND e.DATE_PIECE >= @datePieceDebut";
                parameters.Add(new SqlParameter("@datePieceDebut", dpd.Date));
            }
            if (!string.IsNullOrEmpty(datePieceFin) && DateTime.TryParse(datePieceFin, out dpf))
            {
                whereClause += " AND e.DATE_PIECE <= @datePieceFin";
                parameters.Add(new SqlParameter("@datePieceFin", dpf.Date.AddDays(1)));
            }

            // ⭐ Numéro de pièce (sur REFERENCE ou NUMERO)
            if (!string.IsNullOrEmpty(numeroPiece))
            {
                whereClause += " AND (e.REFERENCE LIKE @numeroPiece OR e.NUMERO LIKE @numeroPiece)";
                parameters.Add(new SqlParameter("@numeroPiece", "%" + numeroPiece + "%"));
            }

            // ⭐ Compte comptable (sur les lignes, via PLAN1..PLAN10)
            if (!string.IsNullOrEmpty(compte))
            {
                whereClause += @" AND EXISTS (
                    SELECT 1 FROM FECRITURE_LIGNE l WHERE l.ECRITURE_ID = e.ID
                      AND (l.PLAN1 LIKE @compte OR l.PLAN2 LIKE @compte
                        OR l.PLAN3 LIKE @compte OR l.PLAN4 LIKE @compte
                        OR l.PLAN5 LIKE @compte OR l.PLAN6 LIKE @compte
                        OR l.PLAN7 LIKE @compte OR l.PLAN8 LIKE @compte
                        OR l.PLAN9 LIKE @compte OR l.PLAN10 LIKE @compte)
                )";
                parameters.Add(new SqlParameter("@compte", compte + "%"));
            }

            // ⭐ Tiers / Auxiliaire
            if (!string.IsNullOrEmpty(tiers))
            {
                whereClause += @" AND EXISTS (
                    SELECT 1 FROM FECRITURE_LIGNE l
                    WHERE l.ECRITURE_ID = e.ID AND l.AUXILIAIRE LIKE @tiers
                )";
                parameters.Add(new SqlParameter("@tiers", "%" + tiers + "%"));
            }

            // ⭐ Marché (champ MARCHE de FECRITURE, texte)
            if (!string.IsNullOrEmpty(marche))
            {
                whereClause += " AND e.MARCHE LIKE @marche";
                parameters.Add(new SqlParameter("@marche", "%" + marche + "%"));
            }

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                // ── COUNT ──
                string countSql = "SELECT COUNT(*) FROM FECRITURE e" + whereClause;
                using (SqlCommand cmd = new SqlCommand(countSql, conn))
                {
                    cmd.Parameters.AddRange(parameters.ToArray());
                    object scalar = cmd.ExecuteScalar();
                    total = (scalar == null || scalar == DBNull.Value) ? 0 : Convert.ToInt32(scalar);
                }

                // ── SELECT PRINCIPAL ──
                string selectSql = @"
                    SELECT e.ID, e.NUMERO, e.DATE_COMPTABLE, e.DATE_PIECE,
                           e.LIBELLE, e.REFERENCE,
                           e.TOTAL_DEBIT, e.TOTAL_CREDIT, e.STATUT,
                           j.CODE AS JOURNAL_CODE, j.LIBELLE AS JOURNAL_LIBELLE,
                           m.CODE AS DEVISE_CODE,
                           ISNULL((SELECT SUM(CASE WHEN l.SENS='D' THEN l.MONTANT_DEVISE ELSE 0 END)
                                     FROM FECRITURE_LIGNE l WHERE l.ECRITURE_ID = e.ID), 0) AS TOTAL_DEBIT_RAP,
                           ISNULL((SELECT SUM(CASE WHEN l.SENS='C' THEN l.MONTANT_DEVISE ELSE 0 END)
                                     FROM FECRITURE_LIGNE l WHERE l.ECRITURE_ID = e.ID), 0) AS TOTAL_CREDIT_RAP
                    FROM FECRITURE e
                    LEFT JOIN FJOURNAL j ON j.ID = e.JOURNAL_ID
                    LEFT JOIN FMONNAIE m ON m.ID = e.MONNAIE_ID
                    " + whereClause + @"
                    ORDER BY e.DATE_COMPTABLE DESC, e.NUMERO DESC
                    OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY";

                using (SqlCommand cmd = new SqlCommand(selectSql, conn))
                {
                    cmd.Parameters.AddRange(parameters.ToArray());
                    cmd.Parameters.AddWithValue("@offset", (page - 1) * pageSize);
                    cmd.Parameters.AddWithValue("@pageSize", pageSize);

                    using (SqlDataReader r = cmd.ExecuteReader())
                    {
                        while (r.Read())
                        {
                            var d = new Dictionary<string, object>();
                            d["ID"]              = r["ID"].ToString();
                            d["NUMERO"]          = r["NUMERO"].ToString();
                            d["DATE_COMPTABLE"]  = Convert.ToDateTime(r["DATE_COMPTABLE"]).ToString("yyyy-MM-dd");
                            d["DATE_PIECE"]      = r["DATE_PIECE"] == DBNull.Value
                                                    ? "" : Convert.ToDateTime(r["DATE_PIECE"]).ToString("yyyy-MM-dd");
                            d["LIBELLE"]         = r["LIBELLE"].ToString();
                            d["REFERENCE"]       = r["REFERENCE"] == DBNull.Value ? "" : r["REFERENCE"].ToString();
                            d["TOTAL_DEBIT"]     = Convert.ToDecimal(r["TOTAL_DEBIT"]);
                            d["TOTAL_CREDIT"]    = Convert.ToDecimal(r["TOTAL_CREDIT"]);
                            d["STATUT"]          = r["STATUT"].ToString();
                            d["JOURNAL_CODE"]    = r["JOURNAL_CODE"] == DBNull.Value ? "" : r["JOURNAL_CODE"].ToString();
                            d["JOURNAL_LIBELLE"] = r["JOURNAL_LIBELLE"] == DBNull.Value ? "" : r["JOURNAL_LIBELLE"].ToString();
                            d["DEVISE_CODE"]     = r["DEVISE_CODE"] == DBNull.Value ? "" : r["DEVISE_CODE"].ToString();
                            d["TOTAL_DEBIT_RAP"]  = Convert.ToDecimal(r["TOTAL_DEBIT_RAP"]);
                            d["TOTAL_CREDIT_RAP"] = Convert.ToDecimal(r["TOTAL_CREDIT_RAP"]);
                            ecritures.Add(d);
                        }
                    }
                }
            }

            int totalPages = (int)Math.Ceiling((double)total / pageSize);
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = true, ecritures = ecritures,
                total = total, totalPages = totalPages,
                page = page, pageSize = pageSize
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
            { success = false, message = ex.Message, type = ex.GetType().Name }));
        }
    }

    public bool IsReusable { get { return false; } }
}

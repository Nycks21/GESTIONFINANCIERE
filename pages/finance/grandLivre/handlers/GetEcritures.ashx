<%@ WebHandler Language="C#" Class="GetEcritures" %>
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

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
            int page = 1, pageSize = 10;
            int.TryParse(ctx.Request.QueryString["page"], out page);
            int.TryParse(ctx.Request.QueryString["pageSize"], out pageSize);
            if (page < 1) page = 1;
            if (pageSize <= 0 || pageSize > 200) pageSize = 10;

            string search  = (ctx.Request.QueryString["search"]  ?? "").Trim();
            string journal = (ctx.Request.QueryString["journalId"] ?? "").Trim();
            string statut  = (ctx.Request.QueryString["statut"]  ?? "").Trim();
            string exerciceId     = (ctx.Request.QueryString["exerciceId"]     ?? "").Trim();

            // ⭐ Nouveaux filtres de référence
            string referenceDebut = (ctx.Request.QueryString["referenceDebut"] ?? "").Trim();
            string referenceFin   = (ctx.Request.QueryString["referenceFin"]   ?? "").Trim();

            string dateDebut      = (ctx.Request.QueryString["dateDebut"]      ?? "").Trim();
            string dateFin        = (ctx.Request.QueryString["dateFin"]        ?? "").Trim();
            string datePieceDebut = (ctx.Request.QueryString["datePieceDebut"] ?? "").Trim();
            string datePieceFin   = (ctx.Request.QueryString["datePieceFin"]   ?? "").Trim();
            string numeroPiece    = (ctx.Request.QueryString["numeroPiece"]    ?? "").Trim();
            string compte         = (ctx.Request.QueryString["compte"]         ?? "").Trim();
            string tiers          = (ctx.Request.QueryString["tiers"]          ?? "").Trim();
            string marche         = (ctx.Request.QueryString["marche"]         ?? "").Trim();
            string site           = (ctx.Request.QueryString["siteId"]         ?? "").Trim();
            string montantMinText = (ctx.Request.QueryString["montantMin"]     ?? "").Trim();
            string montantMaxText = (ctx.Request.QueryString["montantMax"]     ?? "").Trim();

            string connStr = AuthHelper.ConnectionString;
            var ecritures = new List<Dictionary<string, object>>();
            int total = 0;

            string whereClause = " WHERE e.STATUT <> 'ANNULEE'";
            var parameters = new List<SqlParameter>();

            Guid jGuid = Guid.Empty, exGuid = Guid.Empty, siteGuid = Guid.Empty;
            DateTime dd = DateTime.MinValue, df = DateTime.MinValue;
            DateTime dpd = DateTime.MinValue, dpf = DateTime.MinValue;
            decimal montantMin = 0m, montantMax = 0m;
            bool hasMontantMin = !string.IsNullOrEmpty(montantMinText);
            bool hasMontantMax = !string.IsNullOrEmpty(montantMaxText);

            if (!string.IsNullOrEmpty(site) && !Guid.TryParse(site, out siteGuid))
            { ctx.Response.StatusCode = 400; ctx.Response.Write("{\"success\":false,\"message\":\"Site invalide.\"}"); return; }
            if ((hasMontantMin && (!decimal.TryParse(montantMinText, NumberStyles.Number, CultureInfo.InvariantCulture, out montantMin) || montantMin < 0m))
                || (hasMontantMax && (!decimal.TryParse(montantMaxText, NumberStyles.Number, CultureInfo.InvariantCulture, out montantMax) || montantMax < 0m))
                || (hasMontantMin && hasMontantMax && montantMin > montantMax))
            { ctx.Response.StatusCode = 400; ctx.Response.Write("{\"success\":false,\"message\":\"Plage de montants invalide.\"}"); return; }

            if (siteGuid != Guid.Empty) { whereClause += " AND e.SITE_ID = @siteId"; parameters.Add(new SqlParameter("@siteId", SqlDbType.UniqueIdentifier) { Value = siteGuid }); }
            if (!string.IsNullOrEmpty(search)) { whereClause += " AND (e.NUMERO LIKE @search OR e.LIBELLE LIKE @search OR e.REFERENCE LIKE @search)"; parameters.Add(new SqlParameter("@search", "%" + search + "%")); }
            if (!string.IsNullOrEmpty(journal) && Guid.TryParse(journal, out jGuid)) { whereClause += " AND e.JOURNAL_ID = @journal"; parameters.Add(new SqlParameter("@journal", jGuid)); }
            if (!string.IsNullOrEmpty(statut)) { whereClause += " AND e.STATUT = @statut"; parameters.Add(new SqlParameter("@statut", statut)); }
            if (!string.IsNullOrEmpty(exerciceId) && Guid.TryParse(exerciceId, out exGuid)) { whereClause += " AND e.EXERCICE_ID = @exerciceId"; parameters.Add(new SqlParameter("@exerciceId", exGuid)); }

            // ⭐ Filtre Référence de ... à ...
            if (!string.IsNullOrEmpty(referenceDebut))
            {
                whereClause += " AND e.REFERENCE >= @refDebut";
                parameters.Add(new SqlParameter("@refDebut", referenceDebut));
            }
            if (!string.IsNullOrEmpty(referenceFin))
            {
                whereClause += " AND e.REFERENCE <= @refFin";
                parameters.Add(new SqlParameter("@refFin", referenceFin));
            }

            if (!string.IsNullOrEmpty(dateDebut) && DateTime.TryParseExact(dateDebut, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out dd))
            { whereClause += " AND e.DATE_COMPTABLE >= @dateDebut"; parameters.Add(new SqlParameter("@dateDebut", SqlDbType.DateTime) { Value = dd }); }
            if (!string.IsNullOrEmpty(dateFin) && DateTime.TryParseExact(dateFin, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out df))
            { whereClause += " AND e.DATE_COMPTABLE <= @dateFin"; parameters.Add(new SqlParameter("@dateFin", SqlDbType.DateTime) { Value = df }); }

            if (hasMontantMin) { whereClause += " AND (CASE WHEN e.TOTAL_DEBIT >= e.TOTAL_CREDIT THEN e.TOTAL_DEBIT ELSE e.TOTAL_CREDIT END) >= @montantMin"; parameters.Add(new SqlParameter("@montantMin", SqlDbType.Decimal) { Precision = 19, Scale = 4, Value = montantMin }); }
            if (hasMontantMax) { whereClause += " AND (CASE WHEN e.TOTAL_DEBIT >= e.TOTAL_CREDIT THEN e.TOTAL_DEBIT ELSE e.TOTAL_CREDIT END) <= @montantMax"; parameters.Add(new SqlParameter("@montantMax", SqlDbType.Decimal) { Precision = 19, Scale = 4, Value = montantMax }); }

            if (!string.IsNullOrEmpty(datePieceDebut) && DateTime.TryParseExact(datePieceDebut, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out dpd))
            { whereClause += " AND e.DATE_PIECE >= @datePieceDebut"; parameters.Add(new SqlParameter("@datePieceDebut", SqlDbType.DateTime) { Value = dpd }); }
            if (!string.IsNullOrEmpty(datePieceFin) && DateTime.TryParseExact(datePieceFin, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out dpf))
            { whereClause += " AND e.DATE_PIECE <= @datePieceFin"; parameters.Add(new SqlParameter("@datePieceFin", SqlDbType.DateTime) { Value = dpf }); }

            if (!string.IsNullOrEmpty(numeroPiece)) { whereClause += " AND (e.REFERENCE LIKE @numeroPiece OR e.NUMERO LIKE @numeroPiece)"; parameters.Add(new SqlParameter("@numeroPiece", "%" + numeroPiece + "%")); }

            if (!string.IsNullOrEmpty(compte))
            {
                whereClause += @" AND EXISTS (
                    SELECT 1 FROM FECRITURE_LIGNE l
                    INNER JOIN VW_ALL_PLAN_ELEMENTS v ON v.ID = l.COMPTE_ID
                    WHERE l.ECRITURE_ID = e.ID AND v.CODE LIKE @compte
                )";
                parameters.Add(new SqlParameter("@compte", compte + "%"));
            }

            if (!string.IsNullOrEmpty(tiers)) { whereClause += @" AND EXISTS (SELECT 1 FROM FECRITURE_LIGNE l WHERE l.ECRITURE_ID = e.ID AND l.AUXILIAIRE LIKE @tiers)"; parameters.Add(new SqlParameter("@tiers", "%" + tiers + "%")); }
            if (!string.IsNullOrEmpty(marche)) { whereClause += " AND e.MARCHE = @marche"; parameters.Add(new SqlParameter("@marche", marche)); }

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                // ⭐ ÉTAPE 1 : COUNT — on CLONE les paramètres
                string countSql = "SELECT COUNT(*) FROM FECRITURE e" + whereClause;
                using (SqlCommand cmd = new SqlCommand(countSql, conn))
                {
                    cmd.Parameters.AddRange(CloneParameters(parameters));
                    object scalar = cmd.ExecuteScalar();
                    total = (scalar == null || scalar == DBNull.Value) ? 0 : Convert.ToInt32(scalar);
                }

                // ⭐ ÉTAPE 2 : SELECT — on CLONE à nouveau
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
                    cmd.Parameters.AddRange(CloneParameters(parameters));
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
                            d["DATE_PIECE"]      = r["DATE_PIECE"] == DBNull.Value ? "" : Convert.ToDateTime(r["DATE_PIECE"]).ToString("yyyy-MM-dd");
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
            { success = false, message = "SQL Error " + sqlEx.Number + " : " + sqlEx.Message, line = sqlEx.LineNumber }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            { success = false, message = ex.Message, type = ex.GetType().Name }));
        }
    }

    /// <summary>
    /// Clone une liste de SqlParameter — chaque clone est indépendant,
    /// ce qui permet de l'utiliser dans plusieurs SqlCommand successifs.
    /// </summary>
    private static SqlParameter[] CloneParameters(List<SqlParameter> source)
    {
        var clones = new SqlParameter[source.Count];
        for (int i = 0; i < source.Count; i++)
        {
            var p = source[i];
            var clone = new SqlParameter(p.ParameterName, p.SqlDbType);
            clone.Value = p.Value ?? DBNull.Value;
            clone.Direction = p.Direction;
            if (p.Size > 0) clone.Size = p.Size;
            if (p.Precision > 0) clone.Precision = p.Precision;
            if (p.Scale > 0) clone.Scale = p.Scale;
            clones[i] = clone;
        }
        return clones;
    }

    public bool IsReusable { get { return false; } }
}

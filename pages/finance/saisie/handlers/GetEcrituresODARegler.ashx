<%@ WebHandler Language="C#" Class="GetEcrituresODARegler" %>
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetEcrituresODARegler : IHttpHandler, IRequiresSessionState
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
            int page = 1, pageSize = 50;
            int.TryParse(ctx.Request.QueryString["page"], out page);
            int.TryParse(ctx.Request.QueryString["pageSize"], out pageSize);
            if (page < 1) page = 1;
            if (pageSize <= 0 || pageSize > 200) pageSize = 50;

            string compteId   = (ctx.Request.QueryString["compteId"]   ?? "").Trim();
            string auxiliaire = (ctx.Request.QueryString["auxiliaire"] ?? "").Trim();
            string search     = (ctx.Request.QueryString["search"]     ?? "").Trim();
            bool unletteredOnly = string.Equals(
                ctx.Request.QueryString["unletteredOnly"],
                "1",
                StringComparison.Ordinal
            );

            Guid compteGuid;
            if (string.IsNullOrEmpty(compteId) || !Guid.TryParse(compteId, out compteGuid))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"compteId invalide.\"}");
                return;
            }

            string connStr = AuthHelper.ConnectionString;
            var lignes = new List<Dictionary<string, object>>();
            int total = 0;

            // ⭐ CTE pour calculer montant réglé et solde restant
            //    puis filtrer uniquement les lignes avec solde > 0
            string baseSql = @"
                SELECT
                    l.ID              AS ECRITURE_LIGNE_ID,
                    e.ID              AS ECRITURE_ID,
                    e.DATE_PIECE,
                    e.DATE_COMPTABLE,
                    e.NUMERO,
                    e.REFERENCE,
                    e.REFERENCE_FACTURE,
                    e.LIBELLE,
                    j.CODE            AS JOURNAL_CODE,
                    j.CATEGORIE_JOURNAL,
                    p.CODE            AS COMPTE_CODE,
                    l.AUXILIAIRE,
                    l.SENS,
                    l.MONTANT         AS MONTANT_INITIAL,
                    ISNULL(reg.MONTANT_REGLE, 0) AS MONTANT_REGLE,
                    l.MONTANT - ISNULL(reg.MONTANT_REGLE, 0) AS SOLDE_RESTANT,
                    l.PLAN1, l.PLAN2, l.PLAN3, l.PLAN4, l.PLAN5,
                    l.PLAN6, l.PLAN7, l.PLAN8, l.PLAN9, l.PLAN10,
                    l.SOURCE_FINANCEMENT,
                    l.MODE_REGULARISATION,
                    odSource.ID AS SOURCE_IMPUTATION_LINE_ID,
                    odSource.PLAN2 AS SOURCE_PLAN2,
                    odSource.PLAN3 AS SOURCE_PLAN3,
                    odSource.PLAN4 AS SOURCE_PLAN4,
                    odSource.PLAN5 AS SOURCE_PLAN5,
                    odSource.PLAN6 AS SOURCE_PLAN6,
                    odSource.PLAN7 AS SOURCE_PLAN7,
                    odSource.PLAN8 AS SOURCE_PLAN8,
                    odSource.PLAN9 AS SOURCE_PLAN9,
                    odSource.PLAN10 AS SOURCE_PLAN10
                FROM FECRITURE_LIGNE l
                INNER JOIN FECRITURE e ON e.ID = l.ECRITURE_ID
                INNER JOIN FJOURNAL j ON j.ID = e.JOURNAL_ID
                INNER JOIN VW_ALL_PLAN_ELEMENTS p ON p.ID = l.COMPTE_ID
                OUTER APPLY (
                    SELECT TOP (1)
                        sourceLine.ID,
                        sourceLine.PLAN2, sourceLine.PLAN3, sourceLine.PLAN4,
                        sourceLine.PLAN5, sourceLine.PLAN6, sourceLine.PLAN7,
                        sourceLine.PLAN8, sourceLine.PLAN9, sourceLine.PLAN10
                    FROM FECRITURE_LIGNE sourceLine
                    INNER JOIN VW_ALL_PLAN_ELEMENTS sourcePlan1
                        ON sourcePlan1.ID = sourceLine.PLAN1
                       AND sourcePlan1.PLAN_ORDER = 1
                    WHERE sourceLine.ECRITURE_ID = e.ID
                      AND sourceLine.ID <> l.ID
                      AND LEFT(LTRIM(sourcePlan1.CODE), 1) IN ('2', '6')
                    ORDER BY
                        CASE WHEN sourceLine.SENS <> l.SENS
                                  AND sourceLine.MONTANT = l.MONTANT THEN 0 ELSE 1 END,
                        CASE WHEN sourceLine.SENS <> l.SENS THEN 0 ELSE 1 END,
                        sourceLine.ORDRE
                ) odSource
                LEFT JOIN (
                    SELECT fll.ECRITURE_LIGNE_ID, SUM(fll.MONTANT_LETTRE) AS MONTANT_REGLE
                    FROM FLETTRAGE_LIGNE fll
                    INNER JOIN FLETTRAGE f ON f.ID = fll.LETTRAGE_ID
                    WHERE f.DELETION_AT IS NULL
                    GROUP BY fll.ECRITURE_LIGNE_ID
                ) reg ON reg.ECRITURE_LIGNE_ID = l.ID
                WHERE j.CATEGORIE_JOURNAL = 1        -- journal OD
                  AND l.COMPTE_ID = @compteId
                  AND l.LETTRABLE = 1
                  AND l.MONTANT > ISNULL(reg.MONTANT_REGLE, 0)  -- pas totalement réglé
                  AND (@unletteredOnly = 0 OR reg.ECRITURE_LIGNE_ID IS NULL)
                  AND e.STATUT NOT IN ('ANNULEE')";

            var parameters = new List<SqlParameter>();
            parameters.Add(new SqlParameter("@compteId", SqlDbType.UniqueIdentifier) { Value = compteGuid });
            parameters.Add(new SqlParameter("@unletteredOnly", SqlDbType.Bit) { Value = unletteredOnly });

            if (!string.IsNullOrEmpty(auxiliaire))
            {
                baseSql += " AND l.AUXILIAIRE = @aux";
                parameters.Add(new SqlParameter("@aux", SqlDbType.VarChar, 50) { Value = auxiliaire });
            }

            if (!string.IsNullOrEmpty(search))
            {
                baseSql += " AND (e.NUMERO LIKE @s OR e.REFERENCE LIKE @s OR e.LIBELLE LIKE @s)";
                parameters.Add(new SqlParameter("@s", "%" + search + "%"));
            }

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // COUNT sur la requête complète (pour pagination exacte)
                string countSql = "SELECT COUNT(*) FROM (" + baseSql + ") t";
                using (var cmd = new SqlCommand(countSql, conn))
                {
                    cmd.Parameters.AddRange(CloneParameters(parameters));
                    total = Convert.ToInt32(cmd.ExecuteScalar());
                }

                // SELECT paginé
                string selectSql = baseSql + @"
                    ORDER BY e.DATE_PIECE DESC, e.NUMERO DESC
                    OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY";

                using (var cmd = new SqlCommand(selectSql, conn))
                {
                    cmd.Parameters.AddRange(CloneParameters(parameters));
                    cmd.Parameters.AddWithValue("@offset", (page - 1) * pageSize);
                    cmd.Parameters.AddWithValue("@pageSize", pageSize);

                    using (var r = cmd.ExecuteReader())
                    {
                        while (r.Read())
                        {
                            var d = new Dictionary<string, object>();
                            d["ECRITURE_LIGNE_ID"]  = r["ECRITURE_LIGNE_ID"].ToString();
                            d["ECRITURE_ID"]        = r["ECRITURE_ID"].ToString();
                            d["DATE_PIECE"]         = r["DATE_PIECE"] == DBNull.Value ? "" : Convert.ToDateTime(r["DATE_PIECE"]).ToString("yyyy-MM-dd");
                            d["DATE_COMPTABLE"]     = Convert.ToDateTime(r["DATE_COMPTABLE"]).ToString("yyyy-MM-dd");
                            d["NUMERO"]             = r["NUMERO"].ToString();
                            d["REFERENCE"]          = r["REFERENCE"] == DBNull.Value ? "" : r["REFERENCE"].ToString();
                            d["REFERENCE_FACTURE"]  = r["REFERENCE_FACTURE"] == DBNull.Value ? "" : r["REFERENCE_FACTURE"].ToString();
                            d["LIBELLE"]            = r["LIBELLE"].ToString();
                            d["JOURNAL_CODE"]       = r["JOURNAL_CODE"].ToString();
                            d["COMPTE_CODE"]        = r["COMPTE_CODE"].ToString();
                            d["AUXILIAIRE"]         = r["AUXILIAIRE"] == DBNull.Value ? "" : r["AUXILIAIRE"].ToString();
                            d["SENS"]               = r["SENS"] == DBNull.Value ? "" : r["SENS"].ToString();
                            d["MONTANT_INITIAL"]    = r["MONTANT_INITIAL"] == DBNull.Value ? 0m : Convert.ToDecimal(r["MONTANT_INITIAL"]);
                            d["MONTANT_REGLE"]      = Convert.ToDecimal(r["MONTANT_REGLE"]);
                            d["SOLDE_RESTANT"]      = Convert.ToDecimal(r["SOLDE_RESTANT"]);
                            d["SOURCE_FINANCEMENT"] = r["SOURCE_FINANCEMENT"] == DBNull.Value ? "" : r["SOURCE_FINANCEMENT"].ToString();
                            d["MODE_REGULARISATION"] = r["MODE_REGULARISATION"] == DBNull.Value ? "" : r["MODE_REGULARISATION"].ToString();
                            d["SOURCE_IMPUTATION_LINE_ID"] = r["SOURCE_IMPUTATION_LINE_ID"] == DBNull.Value
                                ? null
                                : r["SOURCE_IMPUTATION_LINE_ID"].ToString();

                            for (int k = 1; k <= 10; k++)
                            {
                                d["PLAN" + k] = r["PLAN" + k] == DBNull.Value ? null : r["PLAN" + k].ToString();
                            }
                            for (int k = 2; k <= 10; k++)
                            {
                                d["SOURCE_PLAN" + k] = r["SOURCE_PLAN" + k] == DBNull.Value
                                    ? null
                                    : r["SOURCE_PLAN" + k].ToString();
                            }
                            lignes.Add(d);
                        }
                    }
                }
            }

            int totalPages = (int)Math.Ceiling((double)total / pageSize);
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = true,
                lignes = lignes,
                total = total,
                totalPages = totalPages,
                page = page,
                pageSize = pageSize
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

<%@ WebHandler Language="C#" Class="GetLignesLettrage" %>
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetLignesLettrage : IHttpHandler, IRequiresSessionState
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

            // ⭐ Nouvelles entrées
            string compteId      = (ctx.Request.QueryString["compteId"]      ?? "").Trim();
            string auxiliaire    = (ctx.Request.QueryString["auxiliaire"]    ?? "").Trim();
            string dateDebutText = (ctx.Request.QueryString["dateDebut"]     ?? "").Trim();
            string dateFinText   = (ctx.Request.QueryString["dateFin"]       ?? "").Trim();

            Guid compteGuid;
            if (string.IsNullOrEmpty(compteId) || !Guid.TryParse(compteId, out compteGuid))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"compteId invalide.\"}");
                return;
            }

            string connStr = AuthHelper.ConnectionString;
            var lignes = new List<Dictionary<string, object>>();
            int total = 0;

            string whereClause = @" WHERE l.COMPTE_ID = @compteId
                                      AND l.LETTRABLE = 1
                                      AND NOT EXISTS (
                                          SELECT 1 FROM FLETTRAGE_LIGNE fll
                                          INNER JOIN FLETTRAGE f ON f.ID = fll.LETTRAGE_ID
                                          WHERE fll.ECRITURE_LIGNE_ID = l.ID
                                            AND f.DELETION_AT IS NULL
                                      )";
            var parameters = new List<SqlParameter>();
            parameters.Add(new SqlParameter("@compteId", SqlDbType.UniqueIdentifier) { Value = compteGuid });

            // ⭐ Filtre AUXILIAIRE (code tiers)
            if (!string.IsNullOrEmpty(auxiliaire))
            {
                whereClause += " AND l.AUXILIAIRE = @auxiliaire";
                parameters.Add(new SqlParameter("@auxiliaire", SqlDbType.VarChar, 50) { Value = auxiliaire });
            }

            // ⭐ Filtre DATE COMPTABLE du/au
            DateTime dtDebut;
            if (!string.IsNullOrEmpty(dateDebutText)
                && DateTime.TryParseExact(dateDebutText, "yyyy-MM-dd",
                    CultureInfo.InvariantCulture, DateTimeStyles.None, out dtDebut))
            {
                whereClause += " AND e.DATE_COMPTABLE >= @dateDebut";
                parameters.Add(new SqlParameter("@dateDebut", SqlDbType.Date) { Value = dtDebut });
            }

            DateTime dtFin;
            if (!string.IsNullOrEmpty(dateFinText)
                && DateTime.TryParseExact(dateFinText, "yyyy-MM-dd",
                    CultureInfo.InvariantCulture, DateTimeStyles.None, out dtFin))
            {
                whereClause += " AND e.DATE_COMPTABLE <= @dateFin";
                parameters.Add(new SqlParameter("@dateFin", SqlDbType.Date) { Value = dtFin });
            }

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                string countSql = @"SELECT COUNT(*)
                                    FROM FECRITURE_LIGNE l
                                    INNER JOIN FECRITURE e ON e.ID = l.ECRITURE_ID
                                    " + whereClause;
                using (var cmd = new SqlCommand(countSql, conn))
                {
                    cmd.Parameters.AddRange(CloneParameters(parameters));
                    total = Convert.ToInt32(cmd.ExecuteScalar());
                }

                string selectSql = @"
                    SELECT l.ID, l.LIBELLE, l.SENS, l.MONTANT,
                           e.NUMERO, e.REFERENCE, e.REFERENCE_FACTURE, e.DATE_COMPTABLE,
                           j.CODE AS JOURNAL_CODE,
                           CASE WHEN l.SENS = 'D' THEN l.MONTANT ELSE 0 END AS DEBIT,
                           CASE WHEN l.SENS = 'C' THEN l.MONTANT ELSE 0 END AS CREDIT
                    FROM FECRITURE_LIGNE l
                    INNER JOIN FECRITURE e ON e.ID = l.ECRITURE_ID
                    LEFT JOIN FJOURNAL j ON j.ID = e.JOURNAL_ID
                    " + whereClause + @"
                    ORDER BY e.DATE_COMPTABLE ASC, e.NUMERO ASC
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
                            d["ID"]                = r["ID"].ToString();
                            d["LIBELLE"]           = r["LIBELLE"] == DBNull.Value ? "" : r["LIBELLE"].ToString();
                            d["SENS"]              = r["SENS"] == DBNull.Value ? "" : r["SENS"].ToString();
                            d["MONTANT"]           = r["MONTANT"] == DBNull.Value ? 0m : Convert.ToDecimal(r["MONTANT"]);
                            d["DEBIT"]             = Convert.ToDecimal(r["DEBIT"]);
                            d["CREDIT"]            = Convert.ToDecimal(r["CREDIT"]);
                            d["NUMERO"]            = r["NUMERO"].ToString();
                            d["REFERENCE"]         = r["REFERENCE"] == DBNull.Value ? "" : r["REFERENCE"].ToString();
                            d["REFERENCE_FACTURE"] = r["REFERENCE_FACTURE"] == DBNull.Value ? "" : r["REFERENCE_FACTURE"].ToString();
                            d["DATE_COMPTABLE"]    = Convert.ToDateTime(r["DATE_COMPTABLE"]).ToString("yyyy-MM-dd");
                            d["JOURNAL_CODE"]      = r["JOURNAL_CODE"] == DBNull.Value ? "" : r["JOURNAL_CODE"].ToString();
                            d["LETTRAGE_CODE"]     = ""; // non lettré
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

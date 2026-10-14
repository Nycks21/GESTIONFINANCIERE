<%@ WebHandler Language="C#" Class="GetEcritures" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetEcritures : IHttpHandler, IRequiresSessionState
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
            int page = 1, pageSize = 10;
            int.TryParse(ctx.Request.QueryString["page"], out page);
            int.TryParse(ctx.Request.QueryString["pageSize"], out pageSize);
            if (page < 1) page = 1;
            if (pageSize <= 0) pageSize = 10;

            string search  = (ctx.Request.QueryString["search"] ?? "").Trim();
            string journal = (ctx.Request.QueryString["journalId"] ?? "").Trim();
            string statut  = (ctx.Request.QueryString["statut"] ?? "").Trim();

            string connStr = AuthHelper.ConnectionString;
            var ecritures = new List<Dictionary<string, object>>();
            int total = 0;

            Guid tmp = Guid.Empty;
            bool filterByJournal = false;
            if (!string.IsNullOrEmpty(journal))
            {
                if (Guid.TryParse(journal, out tmp))
                {
                    filterByJournal = true;
                }
            }

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                string whereClause = " WHERE e.STATUT <> 'ANNULEE'";
                var parameters = new List<SqlParameter>();

                if (!string.IsNullOrEmpty(search))
                {
                    whereClause += " AND (e.NUMERO LIKE @search OR e.LIBELLE LIKE @search OR e.REFERENCE LIKE @search)";
                    parameters.Add(new SqlParameter("@search", "%" + search + "%"));
                }
                if (filterByJournal)
                {
                    whereClause += " AND e.JOURNAL_ID = @journal";
                    parameters.Add(new SqlParameter("@journal", tmp));
                }
                if (!string.IsNullOrEmpty(statut))
                {
                    whereClause += " AND e.STATUT = @statut";
                    parameters.Add(new SqlParameter("@statut", statut));
                }

                // ─── COUNT ───
                string countSql = "SELECT COUNT(*) FROM FECRITURE e" + whereClause;
                using (SqlCommand cmd = new SqlCommand(countSql, conn))
                {
                    cmd.Parameters.AddRange(parameters.ToArray());
                    object scalar = cmd.ExecuteScalar();
                    total = (scalar == null || scalar == DBNull.Value) ? 0 : Convert.ToInt32(scalar);
                }

                // ─── SELECT PRINCIPAL (avec 3 nouveaux champs) ───
                string selectSql = @"
                    SELECT e.ID, e.NUMERO, e.DATE_COMPTABLE, e.DATE_PIECE,
                           e.LIBELLE, e.REFERENCE,
                           e.TOTAL_DEBIT, e.TOTAL_CREDIT, e.STATUT,
                           j.CODE AS JOURNAL_CODE, j.LIBELLE AS JOURNAL_LIBELLE,
                           m.CODE AS DEVISE_CODE,
                           ISNULL((
                               SELECT SUM(CASE WHEN l.SENS = 'D' THEN l.MONTANT_DEVISE ELSE 0 END)
                                 FROM FECRITURE_LIGNE l
                                WHERE l.ECRITURE_ID = e.ID
                           ), 0) AS TOTAL_DEBIT_RAP,
                           ISNULL((
                               SELECT SUM(CASE WHEN l.SENS = 'C' THEN l.MONTANT_DEVISE ELSE 0 END)
                                 FROM FECRITURE_LIGNE l
                                WHERE l.ECRITURE_ID = e.ID
                           ), 0) AS TOTAL_CREDIT_RAP
                    FROM FECRITURE e
                    LEFT JOIN FJOURNAL j ON j.ID = e.JOURNAL_ID
                    LEFT JOIN FMONNAIE m ON m.ID = e.MONNAIE_ID
                    " + whereClause + @"
                    ORDER BY e.DATE_COMPTABLE DESC, e.CREATED_AT DESC
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

                            // ⭐ NOUVELLE COLONNE : Date pièce
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

                            // ⭐ NOUVELLES COLONNES : Débit rap / Crédit rap
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
            { success = false, message = ex.Message }));
        }
    }

    public bool IsReusable { get { return false; } }
}

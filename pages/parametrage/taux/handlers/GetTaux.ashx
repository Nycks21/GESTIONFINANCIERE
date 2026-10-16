<%@ WebHandler Language="C#" Class="GetTaux" %>
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetTaux : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        // ─── 1. Permission ───
        try
        {
            if (!AuthHelper.RequireApiPermission(ctx, "taux"))
            {
                ctx.Response.StatusCode = 403;
                ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
                return;
            }
        }
        catch (Exception authEx)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(JsonError("Erreur de permission : " + authEx.Message));
            return;
        }

        try
        {
            // ─── 2. Paramètres (safe parse) ───
            int page = 1;
            int.TryParse(ctx.Request.QueryString["page"], out page);
            if (page < 1) page = 1;

            int pageSize = 10;
            int.TryParse(ctx.Request.QueryString["pageSize"], out pageSize);
            if (pageSize <= 0) pageSize = 10;

            string search    = (ctx.Request.QueryString["search"]   ?? "").Trim();
            string sourceId  = (ctx.Request.QueryString["sourceId"] ?? "").Trim();
            string targetId  = (ctx.Request.QueryString["targetId"] ?? "").Trim();
            string status    = (ctx.Request.QueryString["status"]   ?? "").Trim();
            string sortField = (ctx.Request.QueryString["sort"]     ?? "DATE_EFFET").Trim();
            string sortOrder = (ctx.Request.QueryString["order"]    ?? "DESC").Trim();

            // ✅ Compatible C# 4.0 : variable temporaire au lieu de "out _"
            Guid tmpGuid;

            string connStr = AuthHelper.ConnectionString;
            var taux = new List<Dictionary<string, object>>();
            int total = 0;

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                // ✅ Alias SQL cohérents + [SOURCE] entre crochets
                string baseFrom = @"
                    FROM FTAUX_CHANGE t
                    INNER JOIN FMONNAIE src ON src.ID = t.MONNAIE_SOURCE_ID
                    INNER JOIN FMONNAIE cib ON cib.ID = t.MONNAIE_CIBLE_ID
                    WHERE t.DELETION_AT IS NULL";

                string whereClause = "";
                var parameters = new List<SqlParameter>();

                if (!string.IsNullOrEmpty(search))
                {
                    whereClause += " AND (src.CODE LIKE @search OR src.NOM LIKE @search OR cib.CODE LIKE @search OR cib.NOM LIKE @search)";
                    parameters.Add(new SqlParameter("@search", "%" + search + "%"));
                }

                // ✅ Parse sans "out _"
                if (!string.IsNullOrEmpty(sourceId))
                {
                    if (Guid.TryParse(sourceId, out tmpGuid))
                    {
                        whereClause += " AND t.MONNAIE_SOURCE_ID = @sourceId";
                        parameters.Add(new SqlParameter("@sourceId", tmpGuid));
                    }
                }
                if (!string.IsNullOrEmpty(targetId))
                {
                    if (Guid.TryParse(targetId, out tmpGuid))
                    {
                        whereClause += " AND t.MONNAIE_CIBLE_ID = @targetId";
                        parameters.Add(new SqlParameter("@targetId", tmpGuid));
                    }
                }
                if (!string.IsNullOrEmpty(status))
                {
                    int activeVal;
                    if (int.TryParse(status, out activeVal))
                    {
                        whereClause += " AND t.ACTIVE = @status";
                        parameters.Add(new SqlParameter("@status", activeVal));
                    }
                }

                // ─── 3. COUNT ───
                string countSql = "SELECT COUNT(*)" + baseFrom + whereClause;
                using (SqlCommand cmd = new SqlCommand(countSql, conn))
                {
                    cmd.Parameters.AddRange(parameters.ToArray());
                    object scalar = cmd.ExecuteScalar();
                    total = (scalar == null || scalar == DBNull.Value) ? 0 : Convert.ToInt32(scalar);
                }

                // ─── 4. SELECT paginé ───
                string orderBy = "ORDER BY " + SqlSafeSort(sortField) + " " +
                                 (sortOrder.ToUpper() == "ASC" ? "ASC" : "DESC");

                string selectSql = @"
                    SELECT t.ID,
                           t.MONNAIE_SOURCE_ID, src.CODE AS SOURCE_CODE, src.NOM AS SOURCE_NOM,
                           t.MONNAIE_CIBLE_ID,  cib.CODE AS CIBLE_CODE,  cib.NOM AS CIBLE_NOM,
                           t.TAUX, t.DATE_EFFET, t.[SOURCE], t.ACTIVE
                    " + baseFrom + whereClause + " " + orderBy + @"
                    OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY";

                using (SqlCommand cmd = new SqlCommand(selectSql, conn))
                {
                    cmd.Parameters.AddRange(parameters.ToArray());
                    cmd.Parameters.AddWithValue("@offset", (page - 1) * pageSize);
                    cmd.Parameters.AddWithValue("@pageSize", pageSize);

                    using (SqlDataReader reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            var d = new Dictionary<string, object>();
                            d["ID"]                = reader["ID"].ToString();
                            d["MONNAIE_SOURCE_ID"] = reader["MONNAIE_SOURCE_ID"].ToString();
                            d["SOURCE_CODE"]       = reader["SOURCE_CODE"].ToString();
                            d["SOURCE_NOM"]        = reader["SOURCE_NOM"].ToString();
                            d["MONNAIE_CIBLE_ID"]  = reader["MONNAIE_CIBLE_ID"].ToString();
                            d["CIBLE_CODE"]        = reader["CIBLE_CODE"].ToString();
                            d["CIBLE_NOM"]         = reader["CIBLE_NOM"].ToString();
                            d["TAUX"]              = Convert.ToDecimal(reader["TAUX"]);
                            d["DATE_EFFET"]        = Convert.ToDateTime(reader["DATE_EFFET"]).ToString("yyyy-MM-dd");
                            d["SOURCE"]            = reader["SOURCE"] == DBNull.Value ? "" : reader["SOURCE"].ToString();
                            d["ACTIVE"]            = Convert.ToBoolean(reader["ACTIVE"]);
                            taux.Add(d);
                        }
                    }
                }
            }

            int totalPages = (int)Math.Ceiling((double)total / pageSize);
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success    = true,
                taux       = taux,
                total      = total,
                totalPages = totalPages,
                page       = page,
                pageSize   = pageSize
            }));
        }
        catch (SqlException sqlEx)
        {
            ctx.Response.StatusCode = 500;
            // ✅ On expose le SQL error number + message pour identifier la table/colonne manquante
            ctx.Response.Write(JsonError(
                "SQL Error " + sqlEx.Number + " : " + sqlEx.Message));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(JsonError(ex.Message));
        }
    }

    // ─── Sérialisation JSON sûre (échappe correctement) ───
    private string JsonError(string message)
    {
        var payload = new { success = false, message = message ?? "Erreur inconnue" };
        return new JavaScriptSerializer().Serialize(payload);
    }

    private string SqlSafeSort(string field)
    {
        string upper = (field ?? "").ToUpper();
        switch (upper)
        {
            case "SOURCE_CODE": return "src.CODE";
            case "CIBLE_CODE":  return "cib.CODE";
            case "TAUX":        return "t.TAUX";
            case "DATE_EFFET":  return "t.DATE_EFFET";
            case "ACTIVE":      return "t.ACTIVE";
            default:            return "t.DATE_EFFET";
        }
    }

    public bool IsReusable { get { return false; } }
}

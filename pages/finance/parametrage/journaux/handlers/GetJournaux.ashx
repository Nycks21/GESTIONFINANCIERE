<%@ WebHandler Language="C#" Class="GetJournaux" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetJournaux : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireApiPermission(ctx, "journaux"))
        {
            ctx.Response.StatusCode = 403;
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            int page = 1, pageSize = 10;
            int.TryParse(ctx.Request.QueryString["page"], out page);
            int.TryParse(ctx.Request.QueryString["pageSize"], out pageSize);
            if (page < 1) page = 1;
            if (pageSize <= 0) pageSize = 10;

            string search    = (ctx.Request.QueryString["search"] ?? "").Trim();
            string type      = (ctx.Request.QueryString["type"] ?? "").Trim();
            string categorie = (ctx.Request.QueryString["categorie"] ?? "").Trim();  // 🆕
            string status    = (ctx.Request.QueryString["status"] ?? "").Trim();
            string siteId    = (ctx.Request.QueryString["siteId"] ?? "").Trim();
            string sortField = (ctx.Request.QueryString["sort"] ?? "CODE").Trim();
            string sortOrder = (ctx.Request.QueryString["order"] ?? "ASC").Trim();

            string connStr = AuthHelper.ConnectionString;
            var journaux = new List<Dictionary<string, object>>();
            int total = 0;

            Guid tmpSite = Guid.Empty;
            bool filterBySite = false;
            if (!string.IsNullOrEmpty(siteId))
            {
                if (Guid.TryParse(siteId, out tmpSite)) filterBySite = true;
            }

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                string whereClause = " WHERE j.DELETION_AT IS NULL";
                var parameters = new List<SqlParameter>();

                if (!string.IsNullOrEmpty(search))
                {
                    whereClause += " AND (j.CODE LIKE @search OR j.LIBELLE LIKE @search OR j.PREFIXE_NUMERO LIKE @search)";
                    parameters.Add(new SqlParameter("@search", "%" + search + "%"));
                }
                if (!string.IsNullOrEmpty(type))
                {
                    whereClause += " AND j.TYPE_JOURNAL = @type";
                    parameters.Add(new SqlParameter("@type", type));
                }
                // 🆕 Filtre par catégorie (1 ou 2)
                if (!string.IsNullOrEmpty(categorie))
                {
                    int cat;
                    if (int.TryParse(categorie, out cat) && (cat == 1 || cat == 2))
                    {
                        whereClause += " AND j.CATEGORIE_JOURNAL = @categorie";
                        parameters.Add(new SqlParameter("@categorie", cat));
                    }
                }
                if (!string.IsNullOrEmpty(status))
                {
                    int act;
                    if (int.TryParse(status, out act))
                    {
                        whereClause += " AND j.ACTIVE = @status";
                        parameters.Add(new SqlParameter("@status", act));
                    }
                }
                if (filterBySite)
                {
                    whereClause += " AND EXISTS (SELECT 1 FROM FJOURNAL_SITE js WHERE js.JOURNAL_ID = j.ID AND js.SITE_ID = @filterSite)";
                    parameters.Add(new SqlParameter("@filterSite", tmpSite));
                }

                string countSql = "SELECT COUNT(*) FROM FJOURNAL j" + whereClause;
                using (SqlCommand cmd = new SqlCommand(countSql, conn))
                {
                    cmd.Parameters.AddRange(parameters.ToArray());
                    object scalar = cmd.ExecuteScalar();
                    total = (scalar == null || scalar == DBNull.Value) ? 0 : Convert.ToInt32(scalar);
                }

                string orderBy = "ORDER BY " + SqlSafeSort(sortField) + " " +
                                 (sortOrder.ToUpper() == "DESC" ? "DESC" : "ASC");

                string selectSql = @"
                    SELECT j.ID, j.CODE, j.LIBELLE, j.TYPE_JOURNAL,
                           j.CATEGORIE_JOURNAL,
                           j.MONNAIE_ID, m.CODE AS MONNAIE_CODE,
                           j.COMPTE_BANQUE_ID, j.PLAN_ORDER,
                           j.PREFIXE_NUMERO, j.DERNIER_NUMERO,
                           j.ACTIVE, j.CREATED_AT, j.UPDATED_AT
                    FROM FJOURNAL j
                    LEFT JOIN FMONNAIE m ON m.ID = j.MONNAIE_ID
                    " + whereClause + " " + orderBy + @"
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
                            d["ID"]                = r["ID"].ToString();
                            d["CODE"]              = r["CODE"].ToString();
                            d["LIBELLE"]           = r["LIBELLE"].ToString();
                            d["TYPE_JOURNAL"]      = r["TYPE_JOURNAL"].ToString();
                            d["CATEGORIE_JOURNAL"] = Convert.ToInt32(r["CATEGORIE_JOURNAL"]);  // 🆕
                            d["MONNAIE_ID"]        = r["MONNAIE_ID"] == DBNull.Value ? null : r["MONNAIE_ID"].ToString();
                            d["MONNAIE_CODE"]      = r["MONNAIE_CODE"] == DBNull.Value ? "" : r["MONNAIE_CODE"].ToString();
                            d["COMPTE_BANQUE_ID"]  = r["COMPTE_BANQUE_ID"] == DBNull.Value ? null : r["COMPTE_BANQUE_ID"].ToString();
                            d["PLAN_ORDER"]        = r["PLAN_ORDER"] == DBNull.Value ? (object)null : Convert.ToInt32(r["PLAN_ORDER"]);
                            d["PREFIXE_NUMERO"]    = r["PREFIXE_NUMERO"] == DBNull.Value ? "" : r["PREFIXE_NUMERO"].ToString();
                            d["DERNIER_NUMERO"]    = Convert.ToInt32(r["DERNIER_NUMERO"]);
                            d["ACTIVE"]            = Convert.ToBoolean(r["ACTIVE"]);
                            d["SITES"]             = new List<Dictionary<string, object>>();
                            journaux.Add(d);
                        }
                    }
                }

                // Charge les sites associés
                if (journaux.Count > 0)
                {
                    var ids = new List<string>();
                    foreach (var j in journaux) ids.Add((string)j["ID"]);

                    string inClause = "";
                    for (int i = 0; i < ids.Count; i++)
                    {
                        if (i > 0) inClause += ",";
                        inClause += "@j" + i;
                    }

                    string sqlSites = @"
                        SELECT js.JOURNAL_ID, js.SITE_ID, s.CODE AS SITE_CODE, s.NOM AS SITE_NOM
                        FROM FJOURNAL_SITE js
                        INNER JOIN FSITE s ON s.ID = js.SITE_ID
                        WHERE js.JOURNAL_ID IN (" + inClause + @")
                          AND s.DELETION_AT IS NULL
                        ORDER BY s.CODE";

                    using (SqlCommand cmd = new SqlCommand(sqlSites, conn))
                    {
                        for (int i = 0; i < ids.Count; i++)
                            cmd.Parameters.AddWithValue("@j" + i, ids[i]);

                        var map = new Dictionary<string, List<Dictionary<string, object>>>();
                        using (SqlDataReader r = cmd.ExecuteReader())
                        {
                            while (r.Read())
                            {
                                var jid = r["JOURNAL_ID"].ToString();
                                if (!map.ContainsKey(jid)) map[jid] = new List<Dictionary<string, object>>();
                                var site = new Dictionary<string, object>();
                                site["ID"]   = r["SITE_ID"].ToString();
                                site["CODE"] = r["SITE_CODE"].ToString();
                                site["NOM"]  = r["SITE_NOM"].ToString();
                                map[jid].Add(site);
                            }
                        }
                        foreach (var j in journaux)
                        {
                            var jid = (string)j["ID"];
                            if (map.ContainsKey(jid)) j["SITES"] = map[jid];
                        }
                    }
                }
            }

            int totalPages = (int)Math.Ceiling((double)total / pageSize);
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = true, journaux = journaux,
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

    private string SqlSafeSort(string field)
    {
        string upper = (field ?? "").ToUpper();
        switch (upper)
        {
            case "CODE":              return "j.CODE";
            case "LIBELLE":           return "j.LIBELLE";
            case "TYPE_JOURNAL":      return "j.TYPE_JOURNAL";
            case "CATEGORIE_JOURNAL": return "j.CATEGORIE_JOURNAL";
            case "ACTIVE":            return "j.ACTIVE";
            default:                  return "j.CODE";
        }
    }

    public bool IsReusable { get { return false; } }
}

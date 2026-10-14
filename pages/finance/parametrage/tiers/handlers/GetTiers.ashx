<%@ WebHandler Language="C#" Class="GetTiers" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetTiers : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireApiPermission(ctx, "tiers"))
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

            string search   = (ctx.Request.QueryString["search"] ?? "").Trim();
            string type     = (ctx.Request.QueryString["type"] ?? "").Trim();
            string status   = (ctx.Request.QueryString["status"] ?? "").Trim();
            string compteId = (ctx.Request.QueryString["compteId"] ?? "").Trim();
            string planOrderStr = (ctx.Request.QueryString["planOrder"] ?? "").Trim();
            string sortField = (ctx.Request.QueryString["sort"] ?? "CODE").Trim();
            string sortOrder = (ctx.Request.QueryString["order"] ?? "ASC").Trim();

            string connStr = AuthHelper.ConnectionString;
            var tiers = new List<Dictionary<string, object>>();
            int total = 0;

            Guid tmpCompte = Guid.Empty;
            bool filterByCompte = !string.IsNullOrEmpty(compteId) && Guid.TryParse(compteId, out tmpCompte);

            int filterPlanOrder = 0;
            int.TryParse(planOrderStr, out filterPlanOrder);

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                string whereClause = " WHERE t.DELETION_AT IS NULL";
                var parameters = new List<SqlParameter>();

                if (!string.IsNullOrEmpty(search))
                {
                    whereClause += " AND (t.CODE LIKE @search OR t.NOM LIKE @search OR t.EMAIL LIKE @search OR e.CODE LIKE @search)";
                    parameters.Add(new SqlParameter("@search", "%" + search + "%"));
                }
                if (!string.IsNullOrEmpty(type))
                {
                    whereClause += " AND t.TYPE_TIERS = @type";
                    parameters.Add(new SqlParameter("@type", type));
                }
                if (filterByCompte)
                {
                    whereClause += " AND t.PLAN_ELEMENT_ID = @compte";
                    parameters.Add(new SqlParameter("@compte", tmpCompte));
                }
                if (filterPlanOrder >= 1 && filterPlanOrder <= 10)
                {
                    whereClause += " AND t.PLAN_ORDER = @planOrder";
                    parameters.Add(new SqlParameter("@planOrder", filterPlanOrder));
                }
                if (!string.IsNullOrEmpty(status))
                {
                    int act;
                    if (int.TryParse(status, out act))
                    {
                        whereClause += " AND t.ACTIVE = @status";
                        parameters.Add(new SqlParameter("@status", act));
                    }
                }

                // ✅ Jointure via VW_ALL_PLAN_ELEMENTS (union des 10 tables)
                string baseFrom = @"
                    FROM FTIERS t
                    LEFT JOIN VW_ALL_PLAN_ELEMENTS e
                        ON e.ID = t.PLAN_ELEMENT_ID AND e.PLAN_ORDER = t.PLAN_ORDER";

                string countSql = "SELECT COUNT(*)" + baseFrom + whereClause;
                using (SqlCommand cmd = new SqlCommand(countSql, conn))
                {
                    cmd.Parameters.AddRange(parameters.ToArray());
                    object scalar = cmd.ExecuteScalar();
                    total = (scalar == null || scalar == DBNull.Value) ? 0 : Convert.ToInt32(scalar);
                }

                string orderBy = "ORDER BY " + SqlSafeSort(sortField) + " " +
                                 (sortOrder.ToUpper() == "DESC" ? "DESC" : "ASC");

                string selectSql = @"
                    SELECT t.ID, t.CODE, t.NOM, t.TYPE_TIERS,
                           t.PLAN_ELEMENT_ID, t.PLAN_ORDER,
                           e.CODE    AS COMPTE_CODE,
                           e.LIBELLE AS COMPTE_LIBELLE,
                           t.EMAIL, t.TELEPHONE, t.ADRESSE, t.ACTIVE,
                           t.CREATED_AT, t.UPDATED_AT
                    " + baseFrom + whereClause + " " + orderBy + @"
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
                            d["ID"]               = r["ID"].ToString();
                            d["CODE"]             = r["CODE"].ToString();
                            d["NOM"]              = r["NOM"].ToString();
                            d["TYPE_TIERS"]       = r["TYPE_TIERS"].ToString();
                            d["PLAN_ELEMENT_ID"]  = r["PLAN_ELEMENT_ID"] == DBNull.Value ? null : r["PLAN_ELEMENT_ID"].ToString();
                            d["PLAN_ORDER"]       = r["PLAN_ORDER"] == DBNull.Value ? (object)null : Convert.ToInt32(r["PLAN_ORDER"]);
                            d["COMPTE_CODE"]      = r["COMPTE_CODE"] == DBNull.Value ? "" : r["COMPTE_CODE"].ToString();
                            d["COMPTE_LIBELLE"]   = r["COMPTE_LIBELLE"] == DBNull.Value ? "" : r["COMPTE_LIBELLE"].ToString();
                            d["EMAIL"]            = r["EMAIL"] == DBNull.Value ? "" : r["EMAIL"].ToString();
                            d["TELEPHONE"]        = r["TELEPHONE"] == DBNull.Value ? "" : r["TELEPHONE"].ToString();
                            d["ADRESSE"]          = r["ADRESSE"] == DBNull.Value ? "" : r["ADRESSE"].ToString();
                            d["ACTIVE"]           = Convert.ToBoolean(r["ACTIVE"]);
                            tiers.Add(d);
                        }
                    }
                }
            }

            int totalPages = (int)Math.Ceiling((double)total / pageSize);
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = true, tiers = tiers,
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
            case "CODE":       return "t.CODE";
            case "NOM":        return "t.NOM";
            case "TYPE_TIERS": return "t.TYPE_TIERS";
            case "ACTIVE":     return "t.ACTIVE";
            default:           return "t.CODE";
        }
    }

    public bool IsReusable { get { return false; } }
}

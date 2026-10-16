<%@ WebHandler Language="C#" Class="GetMonnaies" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetMonnaies : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireApiAuth(ctx, -1))
        {
            ctx.Response.StatusCode = 403;
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            int page = Math.Max(1, Convert.ToInt32(ctx.Request.QueryString["page"] ?? "1"));
            int pageSize = Convert.ToInt32(ctx.Request.QueryString["pageSize"] ?? "10");
            if (pageSize <= 0) pageSize = 10;
            string search = (ctx.Request.QueryString["search"] ?? "").Trim();
            string status = (ctx.Request.QueryString["status"] ?? "").Trim();
            string sortField = (ctx.Request.QueryString["sort"] ?? "CODE").Trim();
            string sortOrder = (ctx.Request.QueryString["order"] ?? "ASC").Trim();

            string connStr = AuthHelper.ConnectionString;
            List<Dictionary<string, object>> monnaies = new List<Dictionary<string, object>>();
            int total = 0;

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                string whereClause = "";
                List<SqlParameter> parameters = new List<SqlParameter>();

                if (!string.IsNullOrEmpty(search))
                {
                    whereClause += " AND (CODE LIKE @search OR NOM LIKE @search OR SYMBOLE LIKE @search)";
                    parameters.Add(new SqlParameter("@search", "%" + search + "%"));
                }
                if (!string.IsNullOrEmpty(status))
                {
                    int active = Convert.ToInt32(status);
                    whereClause += " AND ACTIVE = @status";
                    parameters.Add(new SqlParameter("@status", active));
                }

                string countSql = "SELECT COUNT(*) FROM FMONNAIE WHERE DELETION_AT IS NULL" + whereClause;
                using (SqlCommand cmd = new SqlCommand(countSql, conn))
                {
                    cmd.Parameters.AddRange(parameters.ToArray());
                    total = Convert.ToInt32(cmd.ExecuteScalar());
                }

                string orderBy = "ORDER BY " + SqlSafeSort(sortField) + " " + (sortOrder.ToUpper() == "DESC" ? "DESC" : "ASC");
                string selectSql = @"
                    SELECT ID, CODE, NOM, SYMBOLE, DECIMALES, TAUX_REFERENCE, EST_REFERENCE, ACTIVE
                    FROM FMONNAIE
                    WHERE DELETION_AT IS NULL" + whereClause + @"
                    " + orderBy + @"
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
                            Dictionary<string, object> dict = new Dictionary<string, object>();
                            dict["ID"] = reader["ID"].ToString();
                            dict["CODE"] = reader["CODE"];
                            dict["NOM"] = reader["NOM"];
                            dict["SYMBOLE"] = reader["SYMBOLE"] == DBNull.Value ? null : reader["SYMBOLE"];
                            dict["DECIMALES"] = Convert.ToInt32(reader["DECIMALES"]);
                            dict["TAUX_REFERENCE"] = reader["TAUX_REFERENCE"] == DBNull.Value ? null : (object)Convert.ToDecimal(reader["TAUX_REFERENCE"]);
                            dict["EST_REFERENCE"] = Convert.ToBoolean(reader["EST_REFERENCE"]);
                            dict["ACTIVE"] = Convert.ToBoolean(reader["ACTIVE"]);
                            monnaies.Add(dict);
                        }
                    }
                }
            }

            int totalPages = (int)Math.Ceiling((double)total / pageSize);
            var result = new
            {
                success = true,
                Monnaies = monnaies,
                total = total,
                totalPages = totalPages,
                page = page,
                pageSize = pageSize
            };

            ctx.Response.Write(new JavaScriptSerializer().Serialize(result));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    private string SqlSafeSort(string field)
    {
        string upper = field.ToUpper();
        if (upper == "CODE" || upper == "NOM" || upper == "ACTIVE" || upper == "DECIMALES")
            return field;
        return "CODE";
    }

    public bool IsReusable { get { return false; } }
}

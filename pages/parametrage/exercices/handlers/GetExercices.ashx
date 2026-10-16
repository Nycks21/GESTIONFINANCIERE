<%@ WebHandler Language="C#" Class="GetExercices" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetExercices : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        try
        {
            if (!AuthHelper.RequireApiPermission(ctx, "exercices"))
            {
                ctx.Response.StatusCode = 403;
                ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
                return;
            }
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(JsonError("Erreur permission : " + ex.Message));
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
            string status    = (ctx.Request.QueryString["status"] ?? "").Trim();
            string activeStr = (ctx.Request.QueryString["active"] ?? "").Trim();
            string sortField = (ctx.Request.QueryString["sort"]   ?? "DATE_DEBUT").Trim();
            string sortOrder = (ctx.Request.QueryString["order"]  ?? "DESC").Trim();

            string connStr = AuthHelper.ConnectionString;
            var exercices = new List<Dictionary<string, object>>();
            int total = 0;

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                string baseFrom = " FROM FEXERCICE WHERE DELETION_AT IS NULL";
                string whereClause = "";
                var parameters = new List<SqlParameter>();

                if (!string.IsNullOrEmpty(search))
                {
                    whereClause += " AND (CODE LIKE @search OR LIBELLE LIKE @search)";
                    parameters.Add(new SqlParameter("@search", "%" + search + "%"));
                }
                if (!string.IsNullOrEmpty(status))
                {
                    whereClause += " AND STATUT = @status";
                    parameters.Add(new SqlParameter("@status", status));
                }
                if (!string.IsNullOrEmpty(activeStr))
                {
                    int act;
                    if (int.TryParse(activeStr, out act))
                    {
                        whereClause += " AND ACTIVE = @active";
                        parameters.Add(new SqlParameter("@active", act));
                    }
                }

                string countSql = "SELECT COUNT(*)" + baseFrom + whereClause;
                using (SqlCommand cmd = new SqlCommand(countSql, conn))
                {
                    cmd.Parameters.AddRange(parameters.ToArray());
                    object scalar = cmd.ExecuteScalar();
                    total = (scalar == null || scalar == DBNull.Value) ? 0 : Convert.ToInt32(scalar);
                }

                string orderBy = "ORDER BY " + SqlSafeSort(sortField) + " " +
                                 (sortOrder.ToUpper() == "ASC" ? "ASC" : "DESC");

                string selectSql = @"
                    SELECT ID, CODE, LIBELLE, DATE_DEBUT, DATE_FIN, STATUT, ACTIVE,
                           CREATED_AT, CLOTURE_AT
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
                            d["ID"]         = reader["ID"].ToString();
                            d["CODE"]       = reader["CODE"].ToString();
                            d["LIBELLE"]    = reader["LIBELLE"].ToString();
                            d["DATE_DEBUT"] = Convert.ToDateTime(reader["DATE_DEBUT"]).ToString("yyyy-MM-dd");
                            d["DATE_FIN"]   = Convert.ToDateTime(reader["DATE_FIN"]).ToString("yyyy-MM-dd");
                            d["STATUT"]     = reader["STATUT"].ToString();
                            d["ACTIVE"]     = Convert.ToBoolean(reader["ACTIVE"]);
                            d["CREATED_AT"] = reader["CREATED_AT"] == DBNull.Value ? "" : Convert.ToDateTime(reader["CREATED_AT"]).ToString("yyyy-MM-dd");
                            d["CLOTURE_AT"] = reader["CLOTURE_AT"] == DBNull.Value ? "" : Convert.ToDateTime(reader["CLOTURE_AT"]).ToString("yyyy-MM-dd");
                            exercices.Add(d);
                        }
                    }
                }
            }

            int totalPages = (int)Math.Ceiling((double)total / pageSize);
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = true, exercices = exercices,
                total = total, totalPages = totalPages,
                page = page, pageSize = pageSize
            }));
        }
        catch (SqlException sqlEx)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(JsonError("SQL Error " + sqlEx.Number + " : " + sqlEx.Message));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(JsonError(ex.Message));
        }
    }

    private string JsonError(string msg)
    {
        return new JavaScriptSerializer().Serialize(new { success = false, message = msg ?? "Erreur inconnue" });
    }

    private string SqlSafeSort(string field)
    {
        string upper = (field ?? "").ToUpper();
        switch (upper)
        {
            case "CODE":       return "CODE";
            case "LIBELLE":    return "LIBELLE";
            case "DATE_DEBUT": return "DATE_DEBUT";
            case "DATE_FIN":   return "DATE_FIN";
            case "STATUT":     return "STATUT";
            case "ACTIVE":     return "ACTIVE";
            default:           return "DATE_DEBUT";
        }
    }

    public bool IsReusable { get { return false; } }
}

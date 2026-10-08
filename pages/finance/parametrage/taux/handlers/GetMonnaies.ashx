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

        if (!AuthHelper.RequireApiPermission(ctx, "taux"))
        {
            ctx.Response.StatusCode = 403;
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            string connStr = AuthHelper.ConnectionString;
            var monnaies = new List<Dictionary<string, object>>();

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                string sql = @"
                    SELECT ID, CODE, NOM, SYMBOLE, DECIMALES
                    FROM FMONNAIE
                    WHERE ACTIVE = 1 AND DELETION_AT IS NULL
                    ORDER BY CODE";
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                using (SqlDataReader reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        var d = new Dictionary<string, object>();
                        d["ID"]        = reader["ID"].ToString();
                        d["CODE"]      = reader["CODE"];
                        d["NOM"]       = reader["NOM"];
                        d["SYMBOLE"]   = reader["SYMBOLE"] == DBNull.Value ? "" : reader["SYMBOLE"].ToString();
                        d["DECIMALES"] = Convert.ToInt32(reader["DECIMALES"]);
                        monnaies.Add(d);
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = true,
                monnaies = monnaies
            }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = false,
                message = ex.Message.Replace("\"", "\\\"")
            }));
        }
    }

    public bool IsReusable { get { return false; } }
}

<%@ WebHandler Language="C#" Class="GetSections" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetSections : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        try
        {
            if (!AuthHelper.RequireApiPermission(ctx, "generale"))
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
            string connStr = AuthHelper.ConnectionString;
            var sections = new List<Dictionary<string, object>>();

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                string sql = @"
                    SELECT ID, CODE, NOM, ICONE, ORDRE, ACTIVE
                    FROM FPARAMETRE_SECTION
                    WHERE ACTIVE = 1 AND DELETION_AT IS NULL
                    ORDER BY ORDRE, NOM";
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                using (SqlDataReader reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        var d = new Dictionary<string, object>();
                        d["ID"]     = reader["ID"].ToString();
                        d["CODE"]   = reader["CODE"].ToString();
                        d["NOM"]    = reader["NOM"].ToString();
                        d["ICONE"]  = reader["ICONE"] == DBNull.Value ? "" : reader["ICONE"].ToString();
                        d["ORDRE"]  = Convert.ToInt32(reader["ORDRE"]);
                        d["ACTIVE"] = Convert.ToBoolean(reader["ACTIVE"]);
                        sections.Add(d);
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = true,
                sections = sections
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
        return new JavaScriptSerializer().Serialize(new
        { success = false, message = msg ?? "Erreur inconnue" });
    }

    public bool IsReusable { get { return false; } }
}

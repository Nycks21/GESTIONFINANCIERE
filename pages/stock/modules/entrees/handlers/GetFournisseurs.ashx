<%@ WebHandler Language="C#" Class="GetFournisseurs" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetFournisseurs : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        // ✅ Authentification : tous les rôles authentifiés (0 à 4)
        if (!AuthHelper.RequireApiAuth(ctx, -1))
        {
            ctx.Response.StatusCode = 403;
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            string connStr = AuthHelper.ConnectionString;
            var list = new List<object>();
            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // ⭐ NOUVEAU : les fournisseurs viennent de FTIERS, rattachés au plan
                //    comptable via PLAN_ELEMENT_ID. On les identifie par :
                //      • TYPE_TIERS = 'FOURNISSEUR'   (fournisseur explicite)
                //      • OU code du compte collectif PLAN1 commençant par '4' (legacy)
                string sql = @"
                    SELECT
                        f.ID,
                        f.CODE,
                        f.NOM,
                        f.TYPE_TIERS,
                        f.PLAN_ELEMENT_ID,
                        f.PLAN_ORDER,
                        p.CODE AS PLAN_CODE
                    FROM FTIERS f
                    LEFT JOIN PLAN1 p
                        ON p.ID = f.PLAN_ELEMENT_ID
                       AND p.DELETION_AT IS NULL
                    WHERE f.ACTIVE = 1
                      AND f.DELETION_AT IS NULL
                      AND (
                            f.TYPE_TIERS = 'FOURNISSEUR'
                         OR p.CODE LIKE '4%'
                      )
                    ORDER BY f.NOM";

                using (var cmd = new SqlCommand(sql, conn))
                using (var reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        var obj = new Dictionary<string, object>();
                        obj["ID"]             = reader["ID"].ToString();
                        obj["NOM"]            = reader["NOM"].ToString();
                        obj["CODE"]           = reader["CODE"].ToString();
                        obj["TYPE_TIERS"]     = reader["TYPE_TIERS"] != DBNull.Value
                                                ? reader["TYPE_TIERS"].ToString() : null;
                        obj["PLAN_ELEMENT_ID"]= reader["PLAN_ELEMENT_ID"] != DBNull.Value
                                                ? reader["PLAN_ELEMENT_ID"].ToString() : null;
                        obj["PLAN_ORDER"]     = reader["PLAN_ORDER"] != DBNull.Value
                                                ? reader["PLAN_ORDER"].ToString() : null;
                        obj["PLAN_CODE"]      = reader["PLAN_CODE"] != DBNull.Value
                                                ? reader["PLAN_CODE"].ToString() : null;
                        list.Add(obj);
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(
                new { success = true, Fournisseurs = list }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(
                new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    public bool IsReusable { get { return false; } }
}

<%@ WebHandler Language="C#" Class="GetPlanElements" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetPlanElements : IHttpHandler, IRequiresSessionState
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
            int ordre;
            if (!int.TryParse(ctx.Request.QueryString["planOrder"], out ordre) || ordre < 1 || ordre > 10)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"planOrder invalide (1..10).\"}");
                return;
            }

            string tableName = AuthHelperPlan.GetPlanTableName(ordre);
            string connStr = AuthHelper.ConnectionString;
            Dictionary<string, object> plan = null;
            var elements = new List<Dictionary<string, object>>();

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                // Charge les métadonnées du plan
                string sqlPlan = @"
                    SELECT ORDRE, CODE, NOM, NIVEAU, PLAN_TYPE_CODE,
                           (SELECT NOM FROM FPLAN_TYPE WHERE CODE = PLAN_TYPE_CODE) AS TYPE_NOM,
                           ACTIVE
                    FROM FPLAN_HEADER WHERE ORDRE = @o";
                using (SqlCommand cmd = new SqlCommand(sqlPlan, conn))
                {
                    cmd.Parameters.AddWithValue("@o", ordre);
                    using (SqlDataReader r = cmd.ExecuteReader())
                    {
                        if (r.Read())
                        {
                            plan = new Dictionary<string, object>();
                            plan["ORDRE"]           = Convert.ToInt32(r["ORDRE"]);
                            plan["CODE"]            = r["CODE"] == DBNull.Value ? "" : r["CODE"].ToString();
                            plan["NOM"]             = r["NOM"] == DBNull.Value ? "" : r["NOM"].ToString();
                            plan["NIVEAU"]          = Convert.ToInt32(r["NIVEAU"]);
                            plan["PLAN_TYPE_CODE"]  = r["PLAN_TYPE_CODE"] == DBNull.Value ? "" : r["PLAN_TYPE_CODE"].ToString();
                            plan["TYPE_NOM"]        = r["TYPE_NOM"] == DBNull.Value ? "" : r["TYPE_NOM"].ToString();
                            plan["ACTIVE"]          = Convert.ToBoolean(r["ACTIVE"]);
                        }
                    }
                }

                if (plan == null)
                {
                    ctx.Response.Write("{\"success\":false,\"message\":\"Plan introuvable.\"}");
                    return;
                }

                // Charge les éléments de PLANx (table dynamique validée)
                string sqlEl = @"
                    SELECT ID, CODE, LIBELLE, PARENT_ID, NIVEAU, ORDRE,
                           TYPE_ELEMENT, NATURE, ACTIVE, EST_AUXILIAIRE,
                           CASE WHEN EXISTS (
                               SELECT 1 FROM " + tableName + @" c
                               WHERE c.PARENT_ID = t.ID AND c.DELETION_AT IS NULL
                           ) THEN 1 ELSE 0 END AS HAS_CHILDREN
                    FROM " + tableName + @" t
                    WHERE t.DELETION_AT IS NULL
                    ORDER BY t.NIVEAU, t.ORDRE, t.CODE";

                using (SqlCommand cmd = new SqlCommand(sqlEl, conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        var e = new Dictionary<string, object>();
                        e["ID"]              = r["ID"].ToString();
                        e["CODE"]            = r["CODE"].ToString();
                        e["LIBELLE"]         = r["LIBELLE"].ToString();
                        e["PARENT_ID"]       = r["PARENT_ID"] == DBNull.Value ? null : r["PARENT_ID"].ToString();
                        e["NIVEAU"]          = Convert.ToInt32(r["NIVEAU"]);
                        e["ORDRE"]           = Convert.ToInt32(r["ORDRE"]);
                        e["TYPE_ELEMENT"]    = r["TYPE_ELEMENT"] == DBNull.Value ? "DETAIL" : r["TYPE_ELEMENT"].ToString();
                        e["NATURE"]          = r["NATURE"] == DBNull.Value ? "" : r["NATURE"].ToString();
                        e["ACTIVE"]          = Convert.ToBoolean(r["ACTIVE"]);
                        e["EST_AUXILIAIRE"]  = Convert.ToBoolean(r["EST_AUXILIAIRE"]);
                        e["HAS_CHILDREN"]    = Convert.ToInt32(r["HAS_CHILDREN"]) == 1;
                        elements.Add(e);
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = true,
                plan = plan,
                elements = elements
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

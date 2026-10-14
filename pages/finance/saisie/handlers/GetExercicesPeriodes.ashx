<%@ WebHandler Language="C#" Class="GetExercicesPeriodes" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetExercicesPeriodes : IHttpHandler, IRequiresSessionState
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
            string exerciceId = (ctx.Request.QueryString["exerciceId"] ?? "").Trim();
            Guid tmp;
            if (string.IsNullOrEmpty(exerciceId) || !Guid.TryParse(exerciceId, out tmp))
            { ctx.Response.Write("{\"success\":false,\"message\":\"exerciceId invalide.\"}"); return; }

            string connStr = AuthHelper.ConnectionString;
            var periodes = new List<Dictionary<string, object>>();

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (SqlCommand cmd = new SqlCommand(@"
                    SELECT ID, NUMERO, LIBELLE, DATE_DEBUT, DATE_FIN, STATUT
                    FROM FPERIODE
                    WHERE EXERCICE_ID = @ex AND STATUT = 'OUVERTE'
                    ORDER BY NUMERO", conn))
                {
                    cmd.Parameters.AddWithValue("@ex", exerciceId);
                    using (SqlDataReader r = cmd.ExecuteReader())
                    {
                        while (r.Read())
                        {
                            var d = new Dictionary<string, object>();
                            d["ID"]         = r["ID"].ToString();
                            d["NUMERO"]     = Convert.ToInt32(r["NUMERO"]);
                            d["LIBELLE"]    = r["LIBELLE"].ToString();
                            d["DATE_DEBUT"] = Convert.ToDateTime(r["DATE_DEBUT"]).ToString("yyyy-MM-dd");
                            d["DATE_FIN"]   = Convert.ToDateTime(r["DATE_FIN"]).ToString("yyyy-MM-dd");
                            periodes.Add(d);
                        }
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            { success = true, periodes = periodes }));
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

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
        // ⭐ Harmonisé avec GetBalanceGenerale.ashx
        ctx.Response.ContentType = "application/json; charset=utf-8";
        ctx.Response.Charset     = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireApiPermission(ctx, "saisie"))
        {
            ctx.Response.StatusCode = 403;
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            string exerciceIdRaw = (ctx.Request.QueryString["exerciceId"] ?? "").Trim();
            var periodes = new List<Dictionary<string, object>>();
            string connStr = AuthHelper.ConnectionString;

            // ⭐⭐⭐ CORRECTION CS0165 : initialiser à Guid.Empty
            Guid exerciceId = Guid.Empty;
            bool hasExercice = !string.IsNullOrEmpty(exerciceIdRaw)
                            && Guid.TryParse(exerciceIdRaw, out exerciceId);

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                // Si exerciceId fourni → périodes de cet exercice
                // Sinon → périodes de l'exercice OUVERT courant
                string sql = hasExercice
                    ? @"SELECT ID, EXERCICE_ID, NUMERO, LIBELLE, DATE_DEBUT, DATE_FIN, STATUT
                        FROM FPERIODE
                        WHERE EXERCICE_ID = @exId
                        ORDER BY NUMERO"
                    : @"SELECT p.ID, p.EXERCICE_ID, p.NUMERO, p.LIBELLE,
                               p.DATE_DEBUT, p.DATE_FIN, p.STATUT
                        FROM FPERIODE p
                        INNER JOIN FEXERCICE e ON e.ID = p.EXERCICE_ID
                        WHERE e.STATUT = 'OUVERT' AND e.ACTIVE = 1 AND e.DELETION_AT IS NULL
                        ORDER BY p.NUMERO";

                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    if (hasExercice) cmd.Parameters.AddWithValue("@exId", exerciceId);

                    using (SqlDataReader r = cmd.ExecuteReader())
                    {
                        while (r.Read())
                        {
                            var d = new Dictionary<string, object>();
                            d["ID"]           = r["ID"].ToString();
                            d["EXERCICE_ID"]  = r["EXERCICE_ID"].ToString();
                            d["NUMERO"]       = Convert.ToInt32(r["NUMERO"]);
                            d["LIBELLE"]      = r["LIBELLE"].ToString();
                            d["DATE_DEBUT"]   = Convert.ToDateTime(r["DATE_DEBUT"]).ToString("yyyy-MM-dd");
                            d["DATE_FIN"]     = Convert.ToDateTime(r["DATE_FIN"]).ToString("yyyy-MM-dd");
                            d["STATUT"]       = r["STATUT"].ToString();
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
            {
                success = false,
                message = ex.Message,
                type    = ex.GetType().Name
            }));
        }
    }

    public bool IsReusable { get { return false; } }
}

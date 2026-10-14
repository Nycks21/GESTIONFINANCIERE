<%@ WebHandler Language="C#" Class="GetNextNumero" %>
using System;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetNextNumero : IHttpHandler, IRequiresSessionState
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
            string journalId = (ctx.Request.QueryString["journalId"] ?? "").Trim();
            Guid tmp;
            if (string.IsNullOrEmpty(journalId) || !Guid.TryParse(journalId, out tmp))
            { ctx.Response.Write("{\"success\":false,\"message\":\"journalId invalide.\"}"); return; }

            string connStr = AuthHelper.ConnectionString;
            string prefixe = "";
            int dernierNumero = 0;

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (SqlCommand cmd = new SqlCommand(
                    "SELECT PREFIXE_NUMERO, DERNIER_NUMERO FROM FJOURNAL WHERE ID = @id", conn))
                {
                    cmd.Parameters.AddWithValue("@id", journalId);
                    using (SqlDataReader r = cmd.ExecuteReader())
                    {
                        if (r.Read())
                        {
                            prefixe = r["PREFIXE_NUMERO"] == DBNull.Value ? "" : r["PREFIXE_NUMERO"].ToString();
                            dernierNumero = Convert.ToInt32(r["DERNIER_NUMERO"]);
                        }
                    }
                }
            }

            int prochain = dernierNumero + 1;
            string numeroPropose = prefixe + prochain.ToString("D6");

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = true,
                numero = numeroPropose,
                prochainNumero = prochain
            }));
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

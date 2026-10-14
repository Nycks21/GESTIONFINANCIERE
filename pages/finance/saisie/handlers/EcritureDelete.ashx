<%@ WebHandler Language="C#" Class="EcritureDelete" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class EcritureDelete : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireCsrfSafePost(ctx, -1))
        { ctx.Response.StatusCode = 403; ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}"); return; }
        if (!AuthHelper.HasPermission("saisie"))
        { ctx.Response.StatusCode = 403; ctx.Response.Write("{\"success\":false,\"message\":\"Permission refusée\"}"); return; }

        try
        {
            string json = new System.IO.StreamReader(ctx.Request.InputStream).ReadToEnd();
            var serializer = new JavaScriptSerializer();
            var data = serializer.Deserialize<Dictionary<string, object>>(json);
            if (data == null) { ctx.Response.Write("{\"success\":false,\"message\":\"Corps invalide.\"}"); return; }

            string id = GetString(data, "id");
            Guid tmp;
            if (string.IsNullOrEmpty(id) || !Guid.TryParse(id, out tmp))
            { ctx.Response.Write("{\"success\":false,\"message\":\"ID invalide.\"}"); return; }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // Vérif statut : seuls BROUILLON supprimables
                string statut = null;
                using (var cmd = new SqlCommand(
                    "SELECT STATUT FROM FECRITURE WHERE ID = @id", conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    object s = cmd.ExecuteScalar();
                    if (s == null) { ctx.Response.Write("{\"success\":false,\"message\":\"Écriture introuvable.\"}"); return; }
                    statut = s.ToString();
                }

                if (statut != "BROUILLON")
                {
                    ctx.Response.Write(serializer.Serialize(new
                    {
                        success = false,
                        message = "Seules les écritures en BROUILLON peuvent être supprimées (statut actuel : " + statut + ")."
                    }));
                    return;
                }

                // Suppression en cascade (lignes + entête)
                using (var tx = conn.BeginTransaction())
                {
                    try
                    {
                        using (var cmd1 = new SqlCommand(
                            "DELETE FROM FECRITURE_LIGNE WHERE ECRITURE_ID = @id", conn, tx))
                        {
                            cmd1.Parameters.AddWithValue("@id", id);
                            cmd1.ExecuteNonQuery();
                        }

                        using (var cmd2 = new SqlCommand(
                            "DELETE FROM FECRITURE WHERE ID = @id", conn, tx))
                        {
                            cmd2.Parameters.AddWithValue("@id", id);
                            cmd2.ExecuteNonQuery();
                        }

                        try
                        {
                            string ip = ctx.Request.UserHostAddress ?? "";
                            using (var cmdLog = new SqlCommand(@"
                                INSERT INTO SECURITY_LOG (USER_ID, ACTION, DETAILS, IP_ADDRESS, CREATED_AT)
                                VALUES (@u, 'ECRITURE_DELETE', @d, @ip, GETDATE())", conn, tx))
                            {
                                cmdLog.Parameters.AddWithValue("@u", userId);
                                cmdLog.Parameters.AddWithValue("@d", "Écriture supprimée : " + id);
                                cmdLog.Parameters.AddWithValue("@ip", ip);
                                cmdLog.ExecuteNonQuery();
                            }
                        }
                        catch { }

                        tx.Commit();
                    }
                    catch
                    {
                        try { tx.Rollback(); } catch { }
                        throw;
                    }
                }
            }

            ctx.Response.Write(serializer.Serialize(new
            { success = true, message = "Écriture supprimée." }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            { success = false, message = ex.Message }));
        }
    }

    private string GetString(Dictionary<string, object> data, string key)
    { return data.ContainsKey(key) && data[key] != null ? data[key].ToString() : null; }

    public bool IsReusable { get { return false; } }
}

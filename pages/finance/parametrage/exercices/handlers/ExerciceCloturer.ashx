<%@ WebHandler Language="C#" Class="ExerciceCloturer" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ExerciceCloturer : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireCsrfSafePost(ctx, -1))
        { ctx.Response.StatusCode = 403; ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}"); return; }
        if (!AuthHelper.HasPermission("exercices"))
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

                // Récupérer statut actuel
                string statutActuel = null;
                using (var cmd = new SqlCommand(
                    "SELECT STATUT FROM FEXERCICE WHERE ID = @id AND DELETION_AT IS NULL", conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    object s = cmd.ExecuteScalar();
                    if (s == null)
                    { ctx.Response.Write("{\"success\":false,\"message\":\"Exercice introuvable.\"}"); return; }
                    statutActuel = s.ToString();
                }

                if (statutActuel != "OUVERT")
                {
                    ctx.Response.Write(serializer.Serialize(new
                    { success = false, message = "Seul un exercice OUVERT peut être clôturé (statut actuel : " + statutActuel + ")." }));
                    return;
                }

                using (var cmd = new SqlCommand(@"
                    UPDATE FEXERCICE
                    SET STATUT = 'CLOTURE',
                        CLOTURE_BY = @user, CLOTURE_AT = GETDATE(),
                        UPDATED_BY = @user, UPDATED_AT = GETDATE()
                    WHERE ID = @id AND DELETION_AT IS NULL", conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@user", userId);
                    cmd.ExecuteNonQuery();
                }
            }

            ctx.Response.Write(serializer.Serialize(new
            { success = true, message = "Exercice clôturé avec succès." }));
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

<%@ WebHandler Language="C#" Class="ExerciceEdit" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ExerciceEdit : IHttpHandler, IRequiresSessionState
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
            Guid tmpGuid;
            if (string.IsNullOrEmpty(id) || !Guid.TryParse(id, out tmpGuid))
            { ctx.Response.Write("{\"success\":false,\"message\":\"ID invalide.\"}"); return; }

            string code    = (GetString(data, "code") ?? "").Trim().ToUpperInvariant();
            string libelle = (GetString(data, "libelle") ?? "").Trim();
            string statut  = (GetString(data, "statut") ?? "OUVERT").Trim().ToUpperInvariant();
            bool   actif   = GetBool(data, "active", true);

            DateTime dtDebut, dtFin;
            if (!DateTime.TryParse(GetString(data, "dateDebut"), out dtDebut))
            { ctx.Response.Write("{\"success\":false,\"message\":\"Date de début invalide.\"}"); return; }
            if (!DateTime.TryParse(GetString(data, "dateFin"), out dtFin))
            { ctx.Response.Write("{\"success\":false,\"message\":\"Date de fin invalide.\"}"); return; }
            if (dtFin < dtDebut)
            { ctx.Response.Write("{\"success\":false,\"message\":\"La date de fin doit être >= date de début.\"}"); return; }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // Existence
                using (var cmdEx = new SqlCommand(
                    "SELECT COUNT(1) FROM FEXERCICE WHERE ID = @id AND DELETION_AT IS NULL", conn))
                {
                    cmdEx.Parameters.AddWithValue("@id", id);
                    if (Convert.ToInt32(cmdEx.ExecuteScalar()) == 0)
                    { ctx.Response.Write("{\"success\":false,\"message\":\"Exercice introuvable.\"}"); return; }
                }

                // Unicité du code (exclut l'ID courant)
                using (var cmdDup = new SqlCommand(
                    "SELECT COUNT(1) FROM FEXERCICE WHERE CODE = @code AND ID <> @id AND DELETION_AT IS NULL", conn))
                {
                    cmdDup.Parameters.AddWithValue("@code", code);
                    cmdDup.Parameters.AddWithValue("@id", id);
                    if (Convert.ToInt32(cmdDup.ExecuteScalar()) > 0)
                    { ctx.Response.Write("{\"success\":false,\"message\":\"Ce code est utilisé par un autre exercice.\"}"); return; }
                }

                string sql = @"
                    UPDATE FEXERCICE
                    SET CODE = @code, LIBELLE = @libelle,
                        DATE_DEBUT = @dtDebut, DATE_FIN = @dtFin,
                        STATUT = @statut, ACTIVE = @active,
                        UPDATED_BY = @userId, UPDATED_AT = GETDATE()
                    WHERE ID = @id AND DELETION_AT IS NULL";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@code", code);
                    cmd.Parameters.AddWithValue("@libelle", libelle);
                    cmd.Parameters.AddWithValue("@dtDebut", dtDebut);
                    cmd.Parameters.AddWithValue("@dtFin", dtFin);
                    cmd.Parameters.AddWithValue("@statut", statut);
                    cmd.Parameters.AddWithValue("@active", actif ? 1 : 0);
                    cmd.Parameters.AddWithValue("@userId", userId);
                    cmd.ExecuteNonQuery();
                }
            }

            ctx.Response.Write(serializer.Serialize(new
            { success = true, message = "Exercice modifié avec succès." }));
        }
        catch (SqlException sqlEx)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            { success = false, message = "SQL Error " + sqlEx.Number + " : " + sqlEx.Message }));
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

    private bool GetBool(Dictionary<string, object> data, string key, bool def)
    {
        if (data.ContainsKey(key) && data[key] != null)
        {
            bool v; if (bool.TryParse(data[key].ToString(), out v)) return v;
            string s = data[key].ToString().Trim();
            if (s == "1" || s == "true") return true;
            if (s == "0" || s == "false") return false;
        }
        return def;
    }

    public bool IsReusable { get { return false; } }
}

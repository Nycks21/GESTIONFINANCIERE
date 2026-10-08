<%@ WebHandler Language="C#" Class="ExerciceAdd" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ExerciceAdd : IHttpHandler, IRequiresSessionState
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

            string code      = (GetString(data, "code") ?? "").Trim().ToUpperInvariant();
            string libelle   = (GetString(data, "libelle") ?? "").Trim();
            string statut    = (GetString(data, "statut") ?? "OUVERT").Trim().ToUpperInvariant();
            bool   actif     = GetBool(data, "active", true);
            string dateDebutS = GetString(data, "dateDebut");
            string dateFinS   = GetString(data, "dateFin");

            if (string.IsNullOrEmpty(code) || code.Length > 20)
            { ctx.Response.Write("{\"success\":false,\"message\":\"Code obligatoire (max 20).\"}"); return; }
            if (string.IsNullOrEmpty(libelle))
            { ctx.Response.Write("{\"success\":false,\"message\":\"Libellé obligatoire.\"}"); return; }
            if (statut != "OUVERT" && statut != "CLOTURE" && statut != "ARCHIVE")
            { ctx.Response.Write("{\"success\":false,\"message\":\"Statut invalide.\"}"); return; }

            DateTime dtDebut, dtFin;
            if (!DateTime.TryParse(dateDebutS, out dtDebut))
            { ctx.Response.Write("{\"success\":false,\"message\":\"Date de début invalide.\"}"); return; }
            if (!DateTime.TryParse(dateFinS, out dtFin))
            { ctx.Response.Write("{\"success\":false,\"message\":\"Date de fin invalide.\"}"); return; }
            if (dtFin < dtDebut)
            { ctx.Response.Write("{\"success\":false,\"message\":\"La date de fin doit être >= date de début.\"}"); return; }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;
            string newId = Guid.NewGuid().ToString();

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // Unicité du code
                using (var cmdCheck = new SqlCommand(
                    "SELECT COUNT(1) FROM FEXERCICE WHERE CODE = @code AND DELETION_AT IS NULL", conn))
                {
                    cmdCheck.Parameters.AddWithValue("@code", code);
                    if (Convert.ToInt32(cmdCheck.ExecuteScalar()) > 0)
                    { ctx.Response.Write("{\"success\":false,\"message\":\"Ce code d'exercice existe déjà.\"}"); return; }
                }

                // Si OUVERT : clôturer les autres OUVERT (un seul ouvert à la fois)
                if (statut == "OUVERT")
                {
                    using (var cmdClose = new SqlCommand(@"
                        UPDATE FEXERCICE
                        SET STATUT = 'CLOTURE', CLOTURE_BY = @user, CLOTURE_AT = GETDATE(),
                            UPDATED_BY = @user, UPDATED_AT = GETDATE()
                        WHERE STATUT = 'OUVERT' AND DELETION_AT IS NULL", conn))
                    {
                        cmdClose.Parameters.AddWithValue("@user", userId);
                        cmdClose.ExecuteNonQuery();
                    }
                }

                string sqlInsert = @"
                    INSERT INTO FEXERCICE
                        (ID, CODE, LIBELLE, DATE_DEBUT, DATE_FIN, STATUT, ACTIVE,
                         CREATED_BY, CREATED_AT, CLOTURE_BY, CLOTURE_AT)
                    VALUES
                        (@id, @code, @libelle, @dtDebut, @dtFin, @statut, @active,
                         @userId, GETDATE(),
                         CASE WHEN @statut = 'OUVERT' THEN NULL ELSE @userId END,
                         CASE WHEN @statut = 'OUVERT' THEN NULL ELSE GETDATE() END)";

                using (var cmd = new SqlCommand(sqlInsert, conn))
                {
                    cmd.Parameters.AddWithValue("@id", newId);
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
            {
                success = true, id = newId,
                message = "Exercice ajouté avec succès (" + code + ")."
            }));
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

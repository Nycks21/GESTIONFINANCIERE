<%@ WebHandler Language="C#" Class="ExerciceDelete" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ExerciceDelete : IHttpHandler, IRequiresSessionState
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

                // Anti-suppression si l'exercice est OUVERT
                using (var cmdCheck = new SqlCommand(
                    "SELECT STATUT FROM FEXERCICE WHERE ID = @id AND DELETION_AT IS NULL", conn))
                {
                    cmdCheck.Parameters.AddWithValue("@id", id);
                    object statut = cmdCheck.ExecuteScalar();
                    if (statut == null)
                    { ctx.Response.Write("{\"success\":false,\"message\":\"Exercice introuvable.\"}"); return; }
                    if (statut.ToString() == "OUVERT")
                    {
                        ctx.Response.Write(serializer.Serialize(new
                        {
                            success = false,
                            message = "Impossible de supprimer un exercice OUVERT. Clôturez-le d'abord."
                        }));
                        return;
                    }
                }

                // Référence dans FECRITURE ?
                using (var cmdRef = new SqlCommand(
                    "SELECT COUNT(*) FROM FECRITURE WHERE EXERCICE_ID = @id", conn))
                {
                    cmdRef.Parameters.AddWithValue("@id", id);
                    if (Convert.ToInt32(cmdRef.ExecuteScalar()) > 0)
                    {
                        ctx.Response.Write(serializer.Serialize(new
                        {
                            success = false,
                            message = "Impossible : des écritures comptables sont rattachées à cet exercice."
                        }));
                        return;
                    }
                }

                // Soft delete
                string sql = @"
                    UPDATE FEXERCICE
                    SET DELETION_AT = GETDATE(), DELETION_BY = @userId, ACTIVE = 0
                    WHERE ID = @id AND DELETION_AT IS NULL";
                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@userId", userId);
                    int rows = cmd.ExecuteNonQuery();
                    if (rows == 0)
                    { ctx.Response.Write("{\"success\":false,\"message\":\"Exercice introuvable ou déjà supprimé.\"}"); return; }
                }
            }

            ctx.Response.Write(serializer.Serialize(new { success = true, message = "Exercice supprimé." }));
        }
        catch (SqlException sqlEx)
        {
            if (sqlEx.Number == 547)
            {
                ctx.Response.Write(new JavaScriptSerializer().Serialize(new
                { success = false, message = "Impossible : cet exercice est référencé ailleurs." }));
                return;
            }
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

    public bool IsReusable { get { return false; } }
}

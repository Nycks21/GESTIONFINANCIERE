<%@ WebHandler Language="C#" Class="SiteDelete" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class SiteDelete : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        // ✅ Sécurité renforcée : Session + Token CSRF + Origin/Referer
        if (!AuthHelper.RequireCsrfSafePost(ctx, -1))
        {
            ctx.Response.StatusCode = 403;
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }
        if (!AuthHelper.HasPermission("sites"))
        {
            ctx.Response.StatusCode = 403;
            ctx.Response.Write("{\"success\":false,\"message\":\"Permission refusée\"}");
            return;
        }

        try
        {
            string json = new System.IO.StreamReader(ctx.Request.InputStream).ReadToEnd();
            var serializer = new JavaScriptSerializer();
            var data = serializer.Deserialize<Dictionary<string, object>>(json);

            if (data == null)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Corps de requête invalide.\"}");
                return;
            }

            string id = GetString(data, "id");
            if (string.IsNullOrEmpty(id))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"ID manquant.\"}");
                return;
            }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // =====================================================
                // 1) Vérifier existence + récupérer le CODE du site
                // =====================================================
                string code = null;
                using (var cmdExists = new SqlCommand(
                    "SELECT CODE FROM FSITE WHERE ID = @id AND DELETION_AT IS NULL", conn))
                {
                    cmdExists.Parameters.AddWithValue("@id", id);
                    object o = cmdExists.ExecuteScalar();
                    if (o == null || o == DBNull.Value)
                    {
                        ctx.Response.Write("{\"success\":false,\"message\":\"Site introuvable ou déjà supprimé.\"}");
                        return;
                    }
                    code = o.ToString();
                }

                // =====================================================
                // 2) Protéger les sites système 00 et 01 (règle métier)
                // =====================================================
                if (code == "00" || code == "01")
                {
                    ctx.Response.Write(serializer.Serialize(new
                    {
                        success = false,
                        message = "Les sites « 00 — Pour la consolidation » et « 01 — Siège » sont protégés et ne peuvent pas être supprimés."
                    }));
                    return;
                }

                // =====================================================
                // 3) Vérifier les références : FJOURNAL_SITE (liaison)
                // =====================================================
                using (var cmdRef1 = new SqlCommand(
                    "SELECT COUNT(*) FROM FJOURNAL_SITE WHERE SITE_ID = @id", conn))
                {
                    cmdRef1.Parameters.AddWithValue("@id", id);
                    if (Convert.ToInt32(cmdRef1.ExecuteScalar()) > 0)
                    {
                        ctx.Response.Write(serializer.Serialize(new
                        {
                            success = false,
                            message = "Impossible de supprimer : ce site est associé à un ou plusieurs journaux."
                        }));
                        return;
                    }
                }

                // =====================================================
                // 4) Vérifier les références : FECRITURE (SITE_ID)
                // =====================================================
                using (var cmdRef2 = new SqlCommand(
                    "SELECT COUNT(*) FROM FECRITURE WHERE SITE_ID = @id", conn))
                {
                    cmdRef2.Parameters.AddWithValue("@id", id);
                    if (Convert.ToInt32(cmdRef2.ExecuteScalar()) > 0)
                    {
                        ctx.Response.Write(serializer.Serialize(new
                        {
                            success = false,
                            message = "Impossible de supprimer : ce site est utilisé par une ou plusieurs écritures comptables."
                        }));
                        return;
                    }
                }

                // =====================================================
                // 5) Soft delete + nettoyage de EN_COURS
                // =====================================================
                string sql = @"
                    UPDATE FSITE
                    SET DELETION_AT = GETDATE(),
                        DELETION_BY = @userId,
                        EN_COURS    = 0
                    WHERE ID = @id AND DELETION_AT IS NULL";
                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@userId", userId);
                    int rows = cmd.ExecuteNonQuery();
                    if (rows == 0)
                    {
                        ctx.Response.Write("{\"success\":false,\"message\":\"Site introuvable ou déjà supprimé.\"}");
                        return;
                    }
                }
            }

            ctx.Response.Write(serializer.Serialize(new { success = true, message = "Site supprimé." }));
        }
        catch (SqlException ex)
        {
            if (ex.Number == 547)
            {
                ctx.Response.Write(new JavaScriptSerializer().Serialize(new
                {
                    success = false,
                    message = "Impossible de supprimer : ce site est référencé ailleurs."
                }));
                return;
            }
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = false,
                message = ex.Message.Replace("\"", "\\\"")
            }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = false,
                message = ex.Message.Replace("\"", "\\\"")
            }));
        }
    }

    private string GetString(Dictionary<string, object> data, string key)
    {
        return data.ContainsKey(key) && data[key] != null ? data[key].ToString() : null;
    }

    public bool IsReusable { get { return false; } }
}

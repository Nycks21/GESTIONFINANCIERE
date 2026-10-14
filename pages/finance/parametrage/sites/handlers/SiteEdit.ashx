<%@ WebHandler Language="C#" Class="SiteEdit" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Text.RegularExpressions;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class SiteEdit : IHttpHandler, IRequiresSessionState
{
    private static readonly Regex CodeRegex = new Regex(@"^[0-9]{2}$", RegexOptions.Compiled);

    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

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

            string id          = GetString(data, "id");
            string code        = (GetString(data, "code") ?? "").Trim();
            string nom         = (GetString(data, "nom") ?? "").Trim();
            string description = (GetString(data, "description") ?? "").Trim();
            bool   enCours     = GetBool(data, "enCours", false);
            bool   actif       = GetBool(data, "actif", true);

            if (string.IsNullOrEmpty(id))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"ID obligatoire.\"}");
                return;
            }
            if (string.IsNullOrEmpty(code) || !CodeRegex.IsMatch(code))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Le code doit contenir exactement 2 chiffres (de 00 à 99).\"}");
                return;
            }
            if (string.IsNullOrWhiteSpace(nom))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Le nom est obligatoire.\"}");
                return;
            }

            int    userId  = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (var tx = conn.BeginTransaction())
                {
                    try
                    {
                        // 1) Vérifier existence
                        using (var cmdCheck = new SqlCommand(
                            "SELECT COUNT(1) FROM FSITE WHERE ID = @id AND DELETION_AT IS NULL", conn, tx))
                        {
                            cmdCheck.Parameters.AddWithValue("@id", id);
                            if (Convert.ToInt32(cmdCheck.ExecuteScalar()) == 0)
                                throw new Exception("Site introuvable ou déjà supprimé.");
                        }

                        // 2) Anti-doublon sur CODE (hors soi-même)
                        using (var cmdDup = new SqlCommand(
                            "SELECT COUNT(1) FROM FSITE WHERE CODE = @code AND ID <> @id", conn, tx))
                        {
                            cmdDup.Parameters.AddWithValue("@code", code);
                            cmdDup.Parameters.AddWithValue("@id", id);
                            if (Convert.ToInt32(cmdDup.ExecuteScalar()) > 0)
                                throw new Exception("Le code « " + code + " » est déjà utilisé par un autre site.");
                        }

                        // 3) Si EN_COURS = 1 → clear des AUTRES
                        if (enCours)
                        {
                            using (var cmdClear = new SqlCommand(@"
                                UPDATE FSITE WITH (UPDLOCK, HOLDLOCK)
                                SET EN_COURS = 0,
                                    UPDATED_BY = @user,
                                    UPDATED_AT = GETDATE()
                                WHERE EN_COURS = 1
                                  AND ID <> @id
                                  AND DELETION_AT IS NULL", conn, tx))
                            {
                                cmdClear.Parameters.AddWithValue("@id", id);
                                cmdClear.Parameters.AddWithValue("@user", userId);
                                cmdClear.ExecuteNonQuery();
                            }
                        }

                        // 4) Update (CODE inclus)
                        string sql = @"
                            UPDATE FSITE
                            SET CODE = @code,
                                NOM = @nom,
                                DESCRIPTION = @description,
                                EN_COURS = @enCours,
                                ACTIVE = @active,
                                UPDATED_BY = @userId,
                                UPDATED_AT = GETDATE()
                            WHERE ID = @id AND DELETION_AT IS NULL";

                        using (var cmd = new SqlCommand(sql, conn, tx))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            cmd.Parameters.AddWithValue("@code", code);
                            cmd.Parameters.AddWithValue("@nom", nom);
                            cmd.Parameters.AddWithValue("@description",
                                string.IsNullOrEmpty(description) ? (object)DBNull.Value : description);
                            cmd.Parameters.AddWithValue("@enCours", enCours ? 1 : 0);
                            cmd.Parameters.AddWithValue("@active", actif ? 1 : 0);
                            cmd.Parameters.AddWithValue("@userId", userId);

                            int rows = cmd.ExecuteNonQuery();
                            if (rows == 0)
                                throw new Exception("Site introuvable ou déjà supprimé.");
                        }

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
            {
                success = true,
                message = "Site modifié avec succès."
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
    private bool GetBool(Dictionary<string, object> data, string key, bool defaultValue)
    {
        if (data.ContainsKey(key) && data[key] != null)
        {
            bool val;
            if (bool.TryParse(data[key].ToString(), out val)) return val;
            string s = data[key].ToString().Trim();
            if (s == "1" || s == "true") return true;
            if (s == "0" || s == "false") return false;
        }
        return defaultValue;
    }

    public bool IsReusable { get { return false; } }
}

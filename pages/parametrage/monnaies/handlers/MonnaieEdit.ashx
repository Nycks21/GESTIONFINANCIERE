<%@ WebHandler Language="C#" Class="MonnaieEdit" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class MonnaieEdit : IHttpHandler, IRequiresSessionState
{
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
            string code = (GetString(data, "code") ?? "").Trim().ToUpperInvariant();
            string nom = (GetString(data, "nom") ?? "").Trim();
            string symbole = (GetString(data, "symbole") ?? "").Trim();
            int decimales = GetInt(data, "decimales", 2);
            decimal? tauxRef = GetDecimal(data, "tauxReference");
            bool estReference = GetBool(data, "estReference", false);
            bool actif = GetBool(data, "actif", true);

            if (string.IsNullOrEmpty(id) || string.IsNullOrWhiteSpace(code) || string.IsNullOrWhiteSpace(nom))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"ID, code et nom sont obligatoires.\"}");
                return;
            }
            if (code.Length < 2 || code.Length > 10)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Le code doit contenir entre 2 et 10 caractères.\"}");
                return;
            }
            if (decimales < 0 || decimales > 6)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Le nombre de décimales doit être entre 0 et 6.\"}");
                return;
            }

            if (estReference) tauxRef = 1m;

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (var tx = conn.BeginTransaction())
                {
                    try
                    {
                        // Vérifier anti-doublon sur CODE (hors soi-même)
                        using (var cmdCheck = new SqlCommand(
                            "SELECT COUNT(1) FROM FMONNAIE WHERE CODE = @code AND ID <> @id AND DELETION_AT IS NULL", conn, tx))
                        {
                            cmdCheck.Parameters.AddWithValue("@code", code);
                            cmdCheck.Parameters.AddWithValue("@id", id);
                            if (Convert.ToInt32(cmdCheck.ExecuteScalar()) > 0)
                                throw new Exception("Ce code monnaie existe déjà.");
                        }

                        // Si on active EST_REFERENCE, désactiver les autres
                        if (estReference)
                        {
                            using (var cmdUnset = new SqlCommand(
                                "UPDATE FMONNAIE SET EST_REFERENCE = 0 WHERE ID <> @id AND EST_REFERENCE = 1 AND DELETION_AT IS NULL", conn, tx))
                            {
                                cmdUnset.Parameters.AddWithValue("@id", id);
                                cmdUnset.ExecuteNonQuery();
                            }
                        }

                        string sql = @"
                            UPDATE FMONNAIE
                            SET CODE = @code,
                                NOM = @nom,
                                SYMBOLE = @symbole,
                                DECIMALES = @decimales,
                                TAUX_REFERENCE = @tauxRef,
                                EST_REFERENCE = @estRef,
                                ACTIVE = @active,
                                UPDATED_BY = @userId,
                                UPDATED_AT = GETDATE()
                            WHERE ID = @id AND DELETION_AT IS NULL";

                        using (var cmd = new SqlCommand(sql, conn, tx))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            cmd.Parameters.AddWithValue("@code", code);
                            cmd.Parameters.AddWithValue("@nom", nom);
                            cmd.Parameters.AddWithValue("@symbole", (object)symbole ?? DBNull.Value);
                            cmd.Parameters.AddWithValue("@decimales", decimales);
                            cmd.Parameters.AddWithValue("@tauxRef", (object)tauxRef ?? DBNull.Value);
                            cmd.Parameters.AddWithValue("@estRef", estReference ? 1 : 0);
                            cmd.Parameters.AddWithValue("@active", actif ? 1 : 0);
                            cmd.Parameters.AddWithValue("@userId", userId);

                            int rows = cmd.ExecuteNonQuery();
                            if (rows == 0)
                                throw new Exception("Monnaie introuvable ou déjà supprimée.");
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
                message = "Monnaie modifiée avec succès."
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

    private int GetInt(Dictionary<string, object> data, string key, int defaultValue)
    {
        if (data.ContainsKey(key) && data[key] != null)
        {
            int v;
            if (int.TryParse(data[key].ToString(), out v)) return v;
        }
        return defaultValue;
    }

    private decimal? GetDecimal(Dictionary<string, object> data, string key)
    {
        if (data.ContainsKey(key) && data[key] != null)
        {
            string s = data[key].ToString().Trim();
            if (s == "") return null;
            decimal v;
            if (decimal.TryParse(s, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out v))
                return v;
        }
        return null;
    }

    private bool GetBool(Dictionary<string, object> data, string key, bool defaultValue)
    {
        if (data.ContainsKey(key) && data[key] != null)
        {
            bool val;
            if (bool.TryParse(data[key].ToString(), out val)) return val;
            string s = data[key].ToString().Trim();
            if (s == "1") return true;
            if (s == "0") return false;
        }
        return defaultValue;
    }

    public bool IsReusable { get { return false; } }
}

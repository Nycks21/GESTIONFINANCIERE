<%@ WebHandler Language="C#" Class="MonnaieAdd" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class MonnaieAdd : IHttpHandler, IRequiresSessionState
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

            string code = (GetString(data, "code") ?? "").Trim().ToUpperInvariant();
            string nom = (GetString(data, "nom") ?? "").Trim();
            string symbole = (GetString(data, "symbole") ?? "").Trim();
            int decimales = GetInt(data, "decimales", 2);
            decimal? tauxRef = GetDecimal(data, "tauxReference");
            bool estReference = GetBool(data, "estReference", false);
            bool actif = GetBool(data, "actif", true);

            // Validation
            if (string.IsNullOrWhiteSpace(code) || code.Length < 2 || code.Length > 10)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Le code doit contenir entre 2 et 10 caractères.\"}");
                return;
            }
            if (string.IsNullOrWhiteSpace(nom))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Le nom est obligatoire.\"}");
                return;
            }
            if (decimales < 0 || decimales > 6)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Le nombre de décimales doit être entre 0 et 6.\"}");
                return;
            }
            if (estReference && tauxRef.HasValue && tauxRef.Value <= 0)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Une monnaie de référence doit avoir un taux de 1.\"}");
                return;
            }

            // Si référence, forcer taux = 1
            if (estReference) tauxRef = 1m;

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;
            string newId = Guid.NewGuid().ToString();

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (var tx = conn.BeginTransaction())
                {
                    try
                    {
                        // Vérification anti-doublon sur CODE
                        using (var cmdCheck = new SqlCommand(
                            "SELECT COUNT(1) FROM FMONNAIE WHERE CODE = @code AND DELETION_AT IS NULL", conn, tx))
                        {
                            cmdCheck.Parameters.AddWithValue("@code", code);
                            if (Convert.ToInt32(cmdCheck.ExecuteScalar()) > 0)
                                throw new Exception("Ce code monnaie existe déjà.");
                        }

                        // Si on crée une nouvelle référence, désactiver les autres
                        if (estReference)
                        {
                            using (var cmdUnset = new SqlCommand(
                                "UPDATE FMONNAIE SET EST_REFERENCE = 0 WHERE EST_REFERENCE = 1 AND DELETION_AT IS NULL", conn, tx))
                            {
                                cmdUnset.ExecuteNonQuery();
                            }
                        }

                        string sqlInsert = @"
                            INSERT INTO FMONNAIE
                                (ID, CODE, NOM, SYMBOLE, DECIMALES, TAUX_REFERENCE, EST_REFERENCE, ACTIVE,
                                 CREATED_BY, CREATED_AT)
                            VALUES
                                (@id, @code, @nom, @symbole, @decimales, @tauxRef, @estRef, @active,
                                 @userId, GETDATE())";
                        using (var cmd = new SqlCommand(sqlInsert, conn, tx))
                        {
                            cmd.Parameters.AddWithValue("@id", newId);
                            cmd.Parameters.AddWithValue("@code", code);
                            cmd.Parameters.AddWithValue("@nom", nom);
                            cmd.Parameters.AddWithValue("@symbole", (object)symbole ?? DBNull.Value);
                            cmd.Parameters.AddWithValue("@decimales", decimales);
                            cmd.Parameters.AddWithValue("@tauxRef", (object)tauxRef ?? DBNull.Value);
                            cmd.Parameters.AddWithValue("@estRef", estReference ? 1 : 0);
                            cmd.Parameters.AddWithValue("@active", actif ? 1 : 0);
                            cmd.Parameters.AddWithValue("@userId", userId);
                            cmd.ExecuteNonQuery();
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
                id = newId,
                message = "Monnaie ajoutée avec succès (" + code + ")."
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

<%@ WebHandler Language="C#" Class="SiteAdd" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class SiteAdd : IHttpHandler, IRequiresSessionState
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

            string nom = (GetString(data, "nom") ?? "").Trim();
            string description = (GetString(data, "description") ?? "").Trim();
            bool enCours = GetBool(data, "enCours", false);
            bool actif = GetBool(data, "actif", true);

            if (string.IsNullOrWhiteSpace(nom))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Le nom est obligatoire.\"}");
                return;
            }
            if (nom.Length > 200)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Le nom ne doit pas dépasser 200 caractères.\"}");
                return;
            }

            string projetCode = AuthHelper.GetProjectCode(ctx);
            if (string.IsNullOrEmpty(projetCode)) projetCode = "TALIM";
            projetCode = projetCode.Trim().ToUpperInvariant().Replace(" ", "");

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;
            string newId = Guid.NewGuid().ToString();
            string code;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (var tx = conn.BeginTransaction())
                {
                    try
                    {
                        // 1) Séquence
                        string sqlSeq = @"
                            IF NOT EXISTS (
                                SELECT 1 FROM FSITE_SEQUENCE WITH (UPDLOCK, HOLDLOCK)
                                WHERE PROJET_CODE = @projet
                            )
                            BEGIN
                                INSERT INTO FSITE_SEQUENCE (PROJET_CODE, DERNIER_NUMERO)
                                VALUES (@projet, 0);
                            END

                            UPDATE FSITE_SEQUENCE
                            SET DERNIER_NUMERO = DERNIER_NUMERO + 1
                            OUTPUT INSERTED.DERNIER_NUMERO
                            WHERE PROJET_CODE = @projet;";

                        int numero;
                        using (var cmdSeq = new SqlCommand(sqlSeq, conn, tx))
                        {
                            cmdSeq.Parameters.AddWithValue("@projet", projetCode);
                            numero = Convert.ToInt32(cmdSeq.ExecuteScalar());
                        }

                        code = string.Format("SIT-{0}-{1:D5}", projetCode, numero);

                        // 2) Anti-doublon
                        using (var cmdCheck = new SqlCommand(
                            "SELECT COUNT(1) FROM FSITE WHERE CODE = @code", conn, tx))
                        {
                            cmdCheck.Parameters.AddWithValue("@code", code);
                            if (Convert.ToInt32(cmdCheck.ExecuteScalar()) > 0)
                                throw new Exception("Le code généré existe déjà, veuillez réessayer.");
                        }

                        // 3) Si EN_COURS = 1 → clear des autres (atomique)
                        if (enCours)
                        {
                            using (var cmdClear = new SqlCommand(@"
                                UPDATE FSITE WITH (UPDLOCK, HOLDLOCK)
                                SET EN_COURS = 0,
                                    UPDATED_BY = @user,
                                    UPDATED_AT = GETDATE()
                                WHERE EN_COURS = 1
                                  AND DELETION_AT IS NULL", conn, tx))
                            {
                                cmdClear.Parameters.AddWithValue("@user", userId);
                                cmdClear.ExecuteNonQuery();
                            }
                        }

                        // 4) Insert
                        string sqlInsert = @"
                            INSERT INTO FSITE (ID, CODE, NOM, DESCRIPTION, EN_COURS, ACTIVE, CREATED_BY, CREATED_AT)
                            VALUES (@id, @code, @nom, @description, @enCours, @active, @userId, GETDATE())";
                        using (var cmd = new SqlCommand(sqlInsert, conn, tx))
                        {
                            cmd.Parameters.AddWithValue("@id", newId);
                            cmd.Parameters.AddWithValue("@code", code);
                            cmd.Parameters.AddWithValue("@nom", nom);
                            cmd.Parameters.AddWithValue("@description",
                                string.IsNullOrEmpty(description) ? (object)DBNull.Value : description);
                            cmd.Parameters.AddWithValue("@enCours", enCours ? 1 : 0);
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
                code = code,
                message = "Site ajouté avec succès (" + code + ")."
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

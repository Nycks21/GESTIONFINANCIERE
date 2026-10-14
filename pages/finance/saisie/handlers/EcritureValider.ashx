<%@ WebHandler Language="C#" Class="EcritureValider" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class EcritureValider : IHttpHandler, IRequiresSessionState
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
            string newStatut = (GetString(data, "statut") ?? "").Trim().ToUpperInvariant();

            Guid tmp;
            if (string.IsNullOrEmpty(id) || !Guid.TryParse(id, out tmp))
            { ctx.Response.Write("{\"success\":false,\"message\":\"ID invalide.\"}"); return; }

            string[] valid = { "A_VALIDER", "VALIDEE", "COMPTABILISEE", "ANNULEE" };
            if (Array.IndexOf(valid, newStatut) < 0)
            { ctx.Response.Write("{\"success\":false,\"message\":\"Statut cible invalide.\"}"); return; }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (var tx = conn.BeginTransaction())
                {
                    try
                    {
                        string currentStatut = null;
                        decimal totalD = 0, totalC = 0;
                        using (var cmd = new SqlCommand(
                            "SELECT STATUT, TOTAL_DEBIT, TOTAL_CREDIT FROM FECRITURE WHERE ID = @id", conn, tx))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            using (var r = cmd.ExecuteReader())
                            {
                                if (!r.Read()) throw new Exception("Écriture introuvable.");
                                currentStatut = r["STATUT"].ToString();
                                totalD = Convert.ToDecimal(r["TOTAL_DEBIT"]);
                                totalC = Convert.ToDecimal(r["TOTAL_CREDIT"]);
                            }
                        }

                        // Validation : équilibre avant de valider
                        if (newStatut == "VALIDEE" && totalD != totalC)
                            throw new Exception("Impossible de valider une écriture déséquilibrée.");

                        using (var cmd = new SqlCommand(@"
                            UPDATE FECRITURE
                            SET STATUT=@s,
                                VALIDATED_BY = CASE WHEN @s = 'VALIDEE' THEN @u ELSE VALIDATED_BY END,
                                VALIDATED_AT = CASE WHEN @s = 'VALIDEE' THEN GETDATE() ELSE VALIDATED_AT END,
                                UPDATED_BY=@u, UPDATED_AT=GETDATE()
                            WHERE ID=@id", conn, tx))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            cmd.Parameters.AddWithValue("@s", newStatut);
                            cmd.Parameters.AddWithValue("@u", userId);
                            cmd.ExecuteNonQuery();
                        }

                        // Historique
                        try
                        {
                            using (var cmdLog = new SqlCommand(@"
                                INSERT INTO FECRITURE_HISTORIQUE
                                    (ECRITURE_ID, ACTION, STATUT_AVANT, STATUT_APRES, USER_ID, CREATED_AT)
                                VALUES (@eid, 'VALIDATION', @sa, @sp, @u, GETDATE())", conn, tx))
                            {
                                cmdLog.Parameters.AddWithValue("@eid", id);
                                cmdLog.Parameters.AddWithValue("@sa", currentStatut ?? "");
                                cmdLog.Parameters.AddWithValue("@sp", newStatut);
                                cmdLog.Parameters.AddWithValue("@u", userId);
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
            { success = true, message = "Statut mis à jour : " + newStatut }));
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

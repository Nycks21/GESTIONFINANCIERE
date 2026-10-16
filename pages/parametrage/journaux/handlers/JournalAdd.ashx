<%@ WebHandler Language="C#" Class="JournalAdd" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class JournalAdd : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireCsrfSafePost(ctx, -1))
        { ctx.Response.StatusCode = 403; ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}"); return; }
        if (!AuthHelper.HasPermission("journaux"))
        { ctx.Response.StatusCode = 403; ctx.Response.Write("{\"success\":false,\"message\":\"Permission refusée\"}"); return; }

        try
        {
            string json = new System.IO.StreamReader(ctx.Request.InputStream).ReadToEnd();
            var serializer = new JavaScriptSerializer();
            var data = serializer.Deserialize<Dictionary<string, object>>(json);
            if (data == null) { ctx.Response.Write("{\"success\":false,\"message\":\"Corps invalide.\"}"); return; }

            string code          = (GetString(data, "code") ?? "").Trim().ToUpperInvariant();
            string libelle       = (GetString(data, "libelle") ?? "").Trim();
            string type          = (GetString(data, "typeJournal") ?? "").Trim().ToUpperInvariant();
            string monnaieId     = GetString(data, "monnaieId");
            string cptBanque     = GetString(data, "compteBanqueId");
            int    planOrder     = GetInt(data, "planOrder", 0);
            int    categorie     = GetInt(data, "categorieJournal", 1);      // 🆕
            string prefixe       = (GetString(data, "prefixeNumero") ?? "").Trim().ToUpperInvariant();
            bool   active        = GetBool(data, "active", true);
            var    siteIds       = GetGuidList(data, "siteIds");

            if (string.IsNullOrEmpty(code) || code.Length > 20)
            { ctx.Response.Write("{\"success\":false,\"message\":\"Code obligatoire (max 20).\"}"); return; }
            if (string.IsNullOrEmpty(libelle))
            { ctx.Response.Write("{\"success\":false,\"message\":\"Libellé obligatoire.\"}"); return; }

            string[] validTypes = { "ACHATS", "VENTES", "BANQUE", "CAISSE", "OPERATIONS_DIVERSES", "GENERAL" };
            if (Array.IndexOf(validTypes, type) < 0)
            { ctx.Response.Write("{\"success\":false,\"message\":\"Type de journal invalide.\"}"); return; }

            // 🆕 Validation catégorie
            if (categorie != 1 && categorie != 2)
            { ctx.Response.Write("{\"success\":false,\"message\":\"Catégorie invalide (1=OD, 2=Trésorerie).\"}"); return; }

            Guid tmpGuid;

            if (categorie == 2)
            {
                // ─── Trésorerie : compte obligatoire ───
                if (string.IsNullOrEmpty(cptBanque) || !Guid.TryParse(cptBanque, out tmpGuid))
                { ctx.Response.Write("{\"success\":false,\"message\":\"Compte comptable obligatoire pour un journal de trésorerie.\"}"); return; }
                if (planOrder < 1 || planOrder > 10)
                { ctx.Response.Write("{\"success\":false,\"message\":\"Plan du compte invalide.\"}"); return; }

                string tableName = AuthHelperPlan.GetPlanTableName(planOrder);
                string connStrChk = AuthHelper.ConnectionString;
                using (var cnChk = new SqlConnection(connStrChk))
                {
                    cnChk.Open();
                    string sqlChk = "SELECT COUNT(1) FROM " + tableName +
                        " WHERE ID = @id AND ACTIVE = 1 AND DELETION_AT IS NULL";
                    using (var cmdChk = new SqlCommand(sqlChk, cnChk))
                    {
                        cmdChk.Parameters.AddWithValue("@id", cptBanque);
                        if (Convert.ToInt32(cmdChk.ExecuteScalar()) == 0)
                        { ctx.Response.Write("{\"success\":false,\"message\":\"Compte introuvable ou inactif.\"}"); return; }
                    }
                }
            }
            else
            {
                // ─── OD : aucun compte toléré ───
                cptBanque = null;
                planOrder = 0;
            }

            // Validation sites
            if (siteIds.Count > 0)
            {
                string connStr0 = AuthHelper.ConnectionString;
                using (var cn0 = new SqlConnection(connStr0))
                {
                    cn0.Open();
                    foreach (var sid in siteIds)
                    {
                        using (var cmdChk = new SqlCommand(
                            "SELECT COUNT(1) FROM FSITE WHERE ID = @id AND ACTIVE = 1 AND DELETION_AT IS NULL", cn0))
                        {
                            cmdChk.Parameters.AddWithValue("@id", sid);
                            if (Convert.ToInt32(cmdChk.ExecuteScalar()) == 0)
                            {
                                ctx.Response.Write(serializer.Serialize(new
                                { success = false, message = "Site invalide ou inactif : " + sid }));
                                return;
                            }
                        }
                    }
                }
            }

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
                        using (var cmdCheck = new SqlCommand(
                            "SELECT COUNT(1) FROM FJOURNAL WHERE CODE = @code AND DELETION_AT IS NULL", conn, tx))
                        {
                            cmdCheck.Parameters.AddWithValue("@code", code);
                            if (Convert.ToInt32(cmdCheck.ExecuteScalar()) > 0)
                                throw new Exception("Ce code de journal existe déjà.");
                        }

                        string sqlInsert = @"
                            INSERT INTO FJOURNAL
                                (ID, CODE, LIBELLE, TYPE_JOURNAL, CATEGORIE_JOURNAL,
                                 MONNAIE_ID, COMPTE_BANQUE_ID, PLAN_ORDER,
                                 PREFIXE_NUMERO, DERNIER_NUMERO, ACTIVE,
                                 CREATED_BY, CREATED_AT)
                            VALUES
                                (@id, @code, @lib, @type, @categorie,
                                 @monnaie, @cptBanque, @planOrder,
                                 @prefixe, 0, @active,
                                 @userId, GETDATE())";

                        using (var cmd = new SqlCommand(sqlInsert, conn, tx))
                        {
                            cmd.Parameters.AddWithValue("@id", newId);
                            cmd.Parameters.AddWithValue("@code", code);
                            cmd.Parameters.AddWithValue("@lib", libelle);
                            cmd.Parameters.AddWithValue("@type", type);
                            cmd.Parameters.AddWithValue("@categorie", categorie);   // 🆕
                            cmd.Parameters.AddWithValue("@monnaie", string.IsNullOrEmpty(monnaieId) ? (object)DBNull.Value : monnaieId);
                            cmd.Parameters.AddWithValue("@cptBanque", string.IsNullOrEmpty(cptBanque) ? (object)DBNull.Value : cptBanque);
                            cmd.Parameters.AddWithValue("@planOrder", planOrder > 0 ? (object)planOrder : DBNull.Value);
                            cmd.Parameters.AddWithValue("@prefixe", string.IsNullOrEmpty(prefixe) ? (object)DBNull.Value : prefixe);
                            cmd.Parameters.AddWithValue("@active", active ? 1 : 0);
                            cmd.Parameters.AddWithValue("@userId", userId);
                            cmd.ExecuteNonQuery();
                        }

                        foreach (var sid in siteIds)
                        {
                            using (var cmdJs = new SqlCommand(@"
                                INSERT INTO FJOURNAL_SITE (JOURNAL_ID, SITE_ID, CREATED_BY, CREATED_AT)
                                VALUES (@jid, @sid, @uid, GETDATE())", conn, tx))
                            {
                                cmdJs.Parameters.AddWithValue("@jid", newId);
                                cmdJs.Parameters.AddWithValue("@sid", sid);
                                cmdJs.Parameters.AddWithValue("@uid", userId);
                                cmdJs.ExecuteNonQuery();
                            }
                        }

                        try
                        {
                            string ip = ctx.Request.UserHostAddress ?? "";
                            using (var cmdLog = new SqlCommand(@"
                                INSERT INTO SECURITY_LOG (USER_ID, ACTION, DETAILS, IP_ADDRESS, CREATED_AT)
                                VALUES (@uid, 'JOURNAL_ADD', @det, @ip, GETDATE())", conn, tx))
                            {
                                cmdLog.Parameters.AddWithValue("@uid", userId);
                                cmdLog.Parameters.AddWithValue("@det",
                                    code + " - " + libelle + " (" + type + "/CAT" + categorie + ") / sites: " + siteIds.Count);
                                cmdLog.Parameters.AddWithValue("@ip", ip);
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
            {
                success = true,
                id = newId,
                message = "Journal ajouté avec succès (" + code + ")."
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
    private int GetInt(Dictionary<string, object> data, string key, int def)
    {
        int v;
        if (data.ContainsKey(key) && data[key] != null && int.TryParse(data[key].ToString(), out v))
            return v;
        return def;
    }
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
    private List<Guid> GetGuidList(Dictionary<string, object> data, string key)
    {
        var result = new List<Guid>();
        if (!data.ContainsKey(key) || data[key] == null) return result;
        var arr = data[key] as object[];
        if (arr == null)
        {
            Guid g;
            if (Guid.TryParse(data[key].ToString(), out g)) result.Add(g);
            return result;
        }
        foreach (var item in arr)
        {
            if (item == null) continue;
            Guid g;
            if (Guid.TryParse(item.ToString(), out g) && !result.Contains(g))
                result.Add(g);
        }
        return result;
    }

    public bool IsReusable { get { return false; } }
}

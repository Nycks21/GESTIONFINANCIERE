<%@ WebHandler Language="C#" Class="JournalEdit" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class JournalEdit : IHttpHandler, IRequiresSessionState
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

            string id = GetString(data, "id");
            Guid tmpGuid;
            if (string.IsNullOrEmpty(id) || !Guid.TryParse(id, out tmpGuid))
            { ctx.Response.Write("{\"success\":false,\"message\":\"ID invalide.\"}"); return; }

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

            if (string.IsNullOrEmpty(code))    { ctx.Response.Write("{\"success\":false,\"message\":\"Code obligatoire.\"}"); return; }
            if (string.IsNullOrEmpty(libelle)) { ctx.Response.Write("{\"success\":false,\"message\":\"Libellé obligatoire.\"}"); return; }

            string[] validTypes = { "ACHATS", "VENTES", "BANQUE", "CAISSE", "OPERATIONS_DIVERSES", "GENERAL" };
            if (Array.IndexOf(validTypes, type) < 0)
            { ctx.Response.Write("{\"success\":false,\"message\":\"Type de journal invalide.\"}"); return; }

            // 🆕 Validation catégorie
            if (categorie != 1 && categorie != 2)
            { ctx.Response.Write("{\"success\":false,\"message\":\"Catégorie invalide.\"}"); return; }

            if (categorie == 2)
            {
                // Trésorerie : compte obligatoire
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
                // OD : aucun compte
                cptBanque = null;
                planOrder = 0;
            }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (var tx = conn.BeginTransaction())
                {
                    try
                    {
                        using (var cmdEx = new SqlCommand(
                            "SELECT COUNT(1) FROM FJOURNAL WHERE ID = @id AND DELETION_AT IS NULL", conn, tx))
                        {
                            cmdEx.Parameters.AddWithValue("@id", id);
                            if (Convert.ToInt32(cmdEx.ExecuteScalar()) == 0)
                                throw new Exception("Journal introuvable.");
                        }

                        using (var cmdDup = new SqlCommand(@"
                            SELECT COUNT(1) FROM FJOURNAL
                            WHERE CODE = @code AND ID <> @id AND DELETION_AT IS NULL", conn, tx))
                        {
                            cmdDup.Parameters.AddWithValue("@code", code);
                            cmdDup.Parameters.AddWithValue("@id", id);
                            if (Convert.ToInt32(cmdDup.ExecuteScalar()) > 0)
                                throw new Exception("Ce code est utilisé par un autre journal.");
                        }

                        string sql = @"
                            UPDATE FJOURNAL
                            SET CODE = @code,
                                LIBELLE = @lib,
                                TYPE_JOURNAL = @type,
                                CATEGORIE_JOURNAL = @categorie,
                                MONNAIE_ID = @monnaie,
                                COMPTE_BANQUE_ID = @cptBanque,
                                PLAN_ORDER = @planOrder,
                                PREFIXE_NUMERO = @prefixe,
                                ACTIVE = @active,
                                UPDATED_BY = @userId,
                                UPDATED_AT = GETDATE()
                            WHERE ID = @id AND DELETION_AT IS NULL";

                        using (var cmd = new SqlCommand(sql, conn, tx))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
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

                        using (var cmdDel = new SqlCommand(
                            "DELETE FROM FJOURNAL_SITE WHERE JOURNAL_ID = @jid", conn, tx))
                        {
                            cmdDel.Parameters.AddWithValue("@jid", id);
                            cmdDel.ExecuteNonQuery();
                        }

                        foreach (var sid in siteIds)
                        {
                            using (var cmdIns = new SqlCommand(@"
                                INSERT INTO FJOURNAL_SITE (JOURNAL_ID, SITE_ID, CREATED_BY, CREATED_AT)
                                VALUES (@jid, @sid, @uid, GETDATE())", conn, tx))
                            {
                                cmdIns.Parameters.AddWithValue("@jid", id);
                                cmdIns.Parameters.AddWithValue("@sid", sid);
                                cmdIns.Parameters.AddWithValue("@uid", userId);
                                cmdIns.ExecuteNonQuery();
                            }
                        }

                        try
                        {
                            string ip = ctx.Request.UserHostAddress ?? "";
                            using (var cmdLog = new SqlCommand(@"
                                INSERT INTO SECURITY_LOG (USER_ID, ACTION, DETAILS, IP_ADDRESS, CREATED_AT)
                                VALUES (@uid, 'JOURNAL_EDIT', @det, @ip, GETDATE())", conn, tx))
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
            { success = true, message = "Journal modifié avec succès." }));
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

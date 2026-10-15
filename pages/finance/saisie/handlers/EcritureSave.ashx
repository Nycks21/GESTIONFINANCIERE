<%@ WebHandler Language="C#" Class="EcritureSave" %>
using System;
using System.Collections;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class EcritureSave : IHttpHandler, IRequiresSessionState
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

            string id               = GetString(data, "id");
            string exerciceId       = GetString(data, "exerciceId");
            string periodeId        = GetString(data, "periodeId");
            string journalId        = GetString(data, "journalId");
            string monnaieId        = GetString(data, "monnaieId");
            string siteId           = GetString(data, "siteId");
            string numero           = (GetString(data, "numero") ?? "").Trim();
            string dateCmp          = GetString(data, "dateComptable");
            string datePiece        = GetString(data, "datePiece");
            string reference        = (GetString(data, "reference") ?? "").Trim();
            // ⭐ NOUVEAUX CHAMPS
            string referenceFacture = (GetString(data, "referenceFacture") ?? "").Trim();
            string dateFacture      = GetString(data, "dateFacture");
            string libelle          = (GetString(data, "libelle") ?? "").Trim();
            string statut           = (GetString(data, "statut") ?? "BROUILLON").Trim().ToUpperInvariant();

            Guid tmp;
            if (string.IsNullOrEmpty(exerciceId) || !Guid.TryParse(exerciceId, out tmp))
            { ctx.Response.Write("{\"success\":false,\"message\":\"Exercice requis.\"}"); return; }
            if (string.IsNullOrEmpty(journalId) || !Guid.TryParse(journalId, out tmp))
            { ctx.Response.Write("{\"success\":false,\"message\":\"Journal requis.\"}"); return; }
            if (string.IsNullOrEmpty(monnaieId) || !Guid.TryParse(monnaieId, out tmp))
            { ctx.Response.Write("{\"success\":false,\"message\":\"Devise requise.\"}"); return; }
            if (string.IsNullOrEmpty(numero))
            { ctx.Response.Write("{\"success\":false,\"message\":\"Numéro obligatoire.\"}"); return; }
            if (string.IsNullOrEmpty(libelle))
            { ctx.Response.Write("{\"success\":false,\"message\":\"Libellé obligatoire.\"}"); return; }

            Guid siteGuid = Guid.Empty;
            bool hasSite = !string.IsNullOrEmpty(siteId) && Guid.TryParse(siteId, out siteGuid);

            DateTime dtComptable;
            if (!DateTime.TryParse(dateCmp, out dtComptable))
            { ctx.Response.Write("{\"success\":false,\"message\":\"Date comptable invalide.\"}"); return; }

            string[] validStatuts = { "BROUILLON", "A_VALIDER", "VALIDEE" };
            if (Array.IndexOf(validStatuts, statut) < 0)
            { ctx.Response.Write("{\"success\":false,\"message\":\"Statut invalide.\"}"); return; }

            var lignes = GetObjectList(data, "lignes");
            if (lignes.Count == 0)
            { ctx.Response.Write("{\"success\":false,\"message\":\"Au moins une ligne est requise.\"}"); return; }

            // ═══════════════════════════════════════════════════════
            // TOTAUX MONTANT + MONTANT_DEVISE
            // ═══════════════════════════════════════════════════════
            decimal totalD = 0, totalC = 0;
            decimal totalDDevise = 0, totalCDevise = 0;
            var parsedLignes = new List<Dictionary<string, object>>();

            foreach (var l in lignes)
            {
                Guid compteId, tiersId;
                if (string.IsNullOrEmpty(GetString(l, "compteId")) || !Guid.TryParse(GetString(l, "compteId"), out compteId))
                { ctx.Response.Write("{\"success\":false,\"message\":\"Compte manquant sur une ligne.\"}"); return; }

                decimal debit         = GetDecimal(l, "debit", 0);
                decimal credit        = GetDecimal(l, "credit", 0);
                decimal montantDevise = GetDecimal(l, "montantDevise", 0);

                if (debit < 0 || credit < 0 || (debit > 0 && credit > 0) || (debit == 0 && credit == 0))
                { ctx.Response.Write("{\"success\":false,\"message\":\"Montant invalide sur une ligne.\"}"); return; }

                string sens = debit > 0 ? "D" : "C";
                decimal montant = debit > 0 ? debit : credit;

                totalD += debit;
                totalC += credit;
                if (sens == "D") totalDDevise += montantDevise;
                else             totalCDevise += montantDevise;

                var pl = new Dictionary<string, object>();
                pl["ID"]              = GetString(l, "id");
                pl["COMPTE_ID"]       = compteId;
                pl["COMPTE_PLAN_ORDER"] = GetInt(l, "comptePlanOrder", 0);
                pl["TIERS_ID"]        = null;
                string tiersStr = GetString(l, "tiersId");
                if (!string.IsNullOrEmpty(tiersStr) && Guid.TryParse(tiersStr, out tiersId)) pl["TIERS_ID"] = tiersId;
                pl["AUXILIAIRE"]      = GetString(l, "auxiliaire");
                pl["LIBELLE"]         = GetString(l, "libelle");
                pl["SENS"]            = sens;
                pl["MONTANT"]         = montant;
                pl["MONTANT_DEVISE"]  = montantDevise;
                pl["SOURCE_FINANCEMENT"] = GetString(l, "sourceFinancement");

                for (int k = 1; k <= 10; k++)
                {
                    string plVal = GetString(l, "plan" + k);
                    if (!string.IsNullOrEmpty(plVal) && Guid.TryParse(plVal, out tmp))
                        pl["PLAN" + k] = tmp;
                    else
                        pl["PLAN" + k] = null;
                }

                parsedLignes.Add(pl);
            }

            if (totalD != totalC)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Écriture déséquilibrée (MONTANT) : Débit "
                    + totalD.ToString("0.00") + " ≠ Crédit " + totalC.ToString("0.00") + "\"}");
                return;
            }
            if (totalDDevise != totalCDevise)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Écriture déséquilibrée (MONTANT_DEVISE) : Débit "
                    + totalDDevise.ToString("0.00") + " ≠ Crédit " + totalCDevise.ToString("0.00") + "\"}");
                return;
            }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;
            bool isEdit = !string.IsNullOrEmpty(id) && Guid.TryParse(id, out tmp);
            string finalId = isEdit ? id : Guid.NewGuid().ToString();

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (var tx = conn.BeginTransaction())
                {
                    try
                    {
                        string periodeIdFinal = EnsurePeriodeFromExercice(
                            conn, tx, exerciceId, dtComptable, userId);

                        using (var cmdChk = new SqlCommand(@"
                            SELECT COUNT(1) FROM FECRITURE
                            WHERE JOURNAL_ID = @j AND EXERCICE_ID = @e AND NUMERO = @n
                              AND (@id IS NULL OR ID <> @id)", conn, tx))
                        {
                            cmdChk.Parameters.AddWithValue("@j", journalId);
                            cmdChk.Parameters.AddWithValue("@e", exerciceId);
                            cmdChk.Parameters.AddWithValue("@n", numero);
                            cmdChk.Parameters.AddWithValue("@id", isEdit ? (object)id : DBNull.Value);
                            if (Convert.ToInt32(cmdChk.ExecuteScalar()) > 0)
                                throw new Exception("Ce numéro d'écriture existe déjà pour ce journal/exercice.");
                        }

                        if (isEdit)
                        {
                            using (var cmdSt = new SqlCommand(
                                "SELECT STATUT FROM FECRITURE WHERE ID = @id", conn, tx))
                            {
                                cmdSt.Parameters.AddWithValue("@id", id);
                                object st = cmdSt.ExecuteScalar();
                                if (st == null) throw new Exception("Écriture introuvable.");
                                string curStatut = st.ToString();
                                if (curStatut == "COMPTABILISEE" || curStatut == "ANNULEE")
                                    throw new Exception("Écriture non modifiable (statut " + curStatut + ").");
                            }

                            // ⭐ UPDATE avec REFERENCE_FACTURE + DATE_FACTURE
                            using (var cmd = new SqlCommand(@"
                                UPDATE FECRITURE
                                SET EXERCICE_ID=@ex, PERIODE_ID=@pe, JOURNAL_ID=@j,
                                    SITE_ID=@site, MONNAIE_ID=@m,
                                    NUMERO=@n, DATE_COMPTABLE=@dc, DATE_PIECE=@dp,
                                    REFERENCE=@ref, REFERENCE_FACTURE=@refFact, DATE_FACTURE=@dateFact,
                                    LIBELLE=@lib, TOTAL_DEBIT=@td, TOTAL_CREDIT=@tc,
                                    STATUT=@st, UPDATED_BY=@u, UPDATED_AT=GETDATE()
                                WHERE ID=@id", conn, tx))
                            {
                                cmd.Parameters.AddWithValue("@id", id);
                                cmd.Parameters.AddWithValue("@ex", exerciceId);
                                cmd.Parameters.AddWithValue("@pe", periodeIdFinal);
                                cmd.Parameters.AddWithValue("@j", journalId);
                                cmd.Parameters.AddWithValue("@site", hasSite ? (object)siteGuid : DBNull.Value);
                                cmd.Parameters.AddWithValue("@m", monnaieId);
                                cmd.Parameters.AddWithValue("@n", numero);
                                cmd.Parameters.AddWithValue("@dc", dtComptable);
                                cmd.Parameters.AddWithValue("@dp", string.IsNullOrEmpty(datePiece) ? (object)DBNull.Value : DateTime.Parse(datePiece));
                                cmd.Parameters.AddWithValue("@ref", string.IsNullOrEmpty(reference) ? (object)DBNull.Value : reference);
                                // ⭐ NOUVEAU
                                cmd.Parameters.AddWithValue("@refFact", string.IsNullOrEmpty(referenceFacture) ? (object)DBNull.Value : referenceFacture);
                                cmd.Parameters.AddWithValue("@dateFact", string.IsNullOrEmpty(dateFacture) ? (object)DBNull.Value : DateTime.Parse(dateFacture));
                                cmd.Parameters.AddWithValue("@lib", libelle);
                                cmd.Parameters.AddWithValue("@td", totalD);
                                cmd.Parameters.AddWithValue("@tc", totalC);
                                cmd.Parameters.AddWithValue("@st", statut);
                                cmd.Parameters.AddWithValue("@u", userId);
                                cmd.ExecuteNonQuery();
                            }

                            using (var cmdDel = new SqlCommand(
                                "DELETE FROM FECRITURE_LIGNE WHERE ECRITURE_ID = @id", conn, tx))
                            {
                                cmdDel.Parameters.AddWithValue("@id", id);
                                cmdDel.ExecuteNonQuery();
                            }
                        }
                        else
                        {
                            // ⭐ INSERT avec REFERENCE_FACTURE + DATE_FACTURE
                            using (var cmd = new SqlCommand(@"
                                INSERT INTO FECRITURE
                                    (ID, EXERCICE_ID, PERIODE_ID, JOURNAL_ID, SITE_ID, MONNAIE_ID,
                                     NUMERO, DATE_COMPTABLE, DATE_PIECE,
                                     REFERENCE, REFERENCE_FACTURE, DATE_FACTURE,
                                     LIBELLE, TOTAL_DEBIT, TOTAL_CREDIT, STATUT, CREATED_BY, CREATED_AT)
                                VALUES
                                    (@id, @ex, @pe, @j, @site, @m,
                                     @n, @dc, @dp,
                                     @ref, @refFact, @dateFact,
                                     @lib, @td, @tc, @st, @u, GETDATE())", conn, tx))
                            {
                                cmd.Parameters.AddWithValue("@id", finalId);
                                cmd.Parameters.AddWithValue("@ex", exerciceId);
                                cmd.Parameters.AddWithValue("@pe", periodeIdFinal);
                                cmd.Parameters.AddWithValue("@j", journalId);
                                cmd.Parameters.AddWithValue("@site", hasSite ? (object)siteGuid : DBNull.Value);
                                cmd.Parameters.AddWithValue("@m", monnaieId);
                                cmd.Parameters.AddWithValue("@n", numero);
                                cmd.Parameters.AddWithValue("@dc", dtComptable);
                                cmd.Parameters.AddWithValue("@dp", string.IsNullOrEmpty(datePiece) ? (object)DBNull.Value : DateTime.Parse(datePiece));
                                cmd.Parameters.AddWithValue("@ref", string.IsNullOrEmpty(reference) ? (object)DBNull.Value : reference);
                                // ⭐ NOUVEAU
                                cmd.Parameters.AddWithValue("@refFact", string.IsNullOrEmpty(referenceFacture) ? (object)DBNull.Value : referenceFacture);
                                cmd.Parameters.AddWithValue("@dateFact", string.IsNullOrEmpty(dateFacture) ? (object)DBNull.Value : DateTime.Parse(dateFacture));
                                cmd.Parameters.AddWithValue("@lib", libelle);
                                cmd.Parameters.AddWithValue("@td", totalD);
                                cmd.Parameters.AddWithValue("@tc", totalC);
                                cmd.Parameters.AddWithValue("@st", statut);
                                cmd.Parameters.AddWithValue("@u", userId);
                                cmd.ExecuteNonQuery();
                            }
                        }

                        // ⭐ INSERTION DES LIGNES
                        int ordre = 1;
                        foreach (var l in parsedLignes)
                        {
                            using (var cmd = new SqlCommand(@"
                                INSERT INTO FECRITURE_LIGNE
                                    (ID, ECRITURE_ID, ORDRE, COMPTE_ID, COMPTE_PLAN_ORDER, TIERS_ID,
                                     AUXILIAIRE, LIBELLE, SENS, MONTANT, MONTANT_DEVISE,
                                     PLAN1, PLAN2, PLAN3, PLAN4, PLAN5, PLAN6, PLAN7, PLAN8, PLAN9, PLAN10,
                                     SOURCE_FINANCEMENT, CREATED_BY, CREATED_AT)
                                VALUES
                                    (@id, @eid, @o, @cid, @cpo, @tid,
                                     @aux, @lib, @sens, @mnt, @mntdev,
                                     @p1, @p2, @p3, @p4, @p5, @p6, @p7, @p8, @p9, @p10,
                                     @src, @u, GETDATE())", conn, tx))
                            {
                                cmd.Parameters.AddWithValue("@id", Guid.NewGuid().ToString());
                                cmd.Parameters.AddWithValue("@eid", finalId);
                                cmd.Parameters.AddWithValue("@o", ordre++);
                                cmd.Parameters.AddWithValue("@cid", l["COMPTE_ID"]);
                                cmd.Parameters.AddWithValue("@cpo", l["COMPTE_PLAN_ORDER"] == null || (int)l["COMPTE_PLAN_ORDER"] == 0 ? (object)DBNull.Value : l["COMPTE_PLAN_ORDER"]);
                                cmd.Parameters.AddWithValue("@tid", l["TIERS_ID"] ?? (object)DBNull.Value);
                                cmd.Parameters.AddWithValue("@aux", string.IsNullOrEmpty((string)l["AUXILIAIRE"]) ? (object)DBNull.Value : l["AUXILIAIRE"]);
                                cmd.Parameters.AddWithValue("@lib", string.IsNullOrEmpty((string)l["LIBELLE"]) ? (object)DBNull.Value : l["LIBELLE"]);
                                cmd.Parameters.AddWithValue("@sens", l["SENS"]);
                                cmd.Parameters.AddWithValue("@mnt", l["MONTANT"]);
                                decimal mntDev = (decimal)l["MONTANT_DEVISE"];
                                cmd.Parameters.AddWithValue("@mntdev", mntDev != 0 ? (object)mntDev : DBNull.Value);
                                cmd.Parameters.AddWithValue("@p1",  l["PLAN1"]  ?? (object)DBNull.Value);
                                cmd.Parameters.AddWithValue("@p2",  l["PLAN2"]  ?? (object)DBNull.Value);
                                cmd.Parameters.AddWithValue("@p3",  l["PLAN3"]  ?? (object)DBNull.Value);
                                cmd.Parameters.AddWithValue("@p4",  l["PLAN4"]  ?? (object)DBNull.Value);
                                cmd.Parameters.AddWithValue("@p5",  l["PLAN5"]  ?? (object)DBNull.Value);
                                cmd.Parameters.AddWithValue("@p6",  l["PLAN6"]  ?? (object)DBNull.Value);
                                cmd.Parameters.AddWithValue("@p7",  l["PLAN7"]  ?? (object)DBNull.Value);
                                cmd.Parameters.AddWithValue("@p8",  l["PLAN8"]  ?? (object)DBNull.Value);
                                cmd.Parameters.AddWithValue("@p9",  l["PLAN9"]  ?? (object)DBNull.Value);
                                cmd.Parameters.AddWithValue("@p10", l["PLAN10"] ?? (object)DBNull.Value);
                                cmd.Parameters.AddWithValue("@src", string.IsNullOrEmpty((string)l["SOURCE_FINANCEMENT"]) ? (object)DBNull.Value : l["SOURCE_FINANCEMENT"]);
                                cmd.Parameters.AddWithValue("@u", userId);
                                cmd.ExecuteNonQuery();
                            }
                        }

                        if (!isEdit)
                        {
                            using (var cmdUpd = new SqlCommand(@"
                                UPDATE FJOURNAL SET DERNIER_NUMERO = DERNIER_NUMERO + 1
                                WHERE ID = @j", conn, tx))
                            {
                                cmdUpd.Parameters.AddWithValue("@j", journalId);
                                cmdUpd.ExecuteNonQuery();
                            }
                        }

                        // Audit
                        try
                        {
                            string ip = ctx.Request.UserHostAddress ?? "";
                            using (var cmdLog = new SqlCommand(@"
                                INSERT INTO SECURITY_LOG (USER_ID, ACTION, DETAILS, IP_ADDRESS, CREATED_AT)
                                VALUES (@u, @a, @d, @ip, GETDATE())", conn, tx))
                            {
                                cmdLog.Parameters.AddWithValue("@u", userId);
                                cmdLog.Parameters.AddWithValue("@a", isEdit ? "ECRITURE_EDIT" : "ECRITURE_ADD");
                                cmdLog.Parameters.AddWithValue("@d", numero + " - " + libelle
                                    + " (M=" + totalD.ToString("0.00") + " / MD=" + totalDDevise.ToString("0.00") + ")");
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
                id = finalId,
                message = isEdit ? "Écriture modifiée." : "Écriture créée."
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

    // ============================================================
    // Résolution / auto-création de la période
    // ============================================================
    private string EnsurePeriodeFromExercice(
        SqlConnection conn, SqlTransaction tx,
        string exerciceId, DateTime dateComptable, int userId)
    {
        using (var cmd = new SqlCommand(@"
            SELECT TOP 1 ID FROM FPERIODE
             WHERE EXERCICE_ID = @ex AND @d BETWEEN DATE_DEBUT AND DATE_FIN
             ORDER BY NUMERO", conn, tx))
        {
            cmd.Parameters.AddWithValue("@ex", exerciceId);
            cmd.Parameters.AddWithValue("@d",  dateComptable.Date);
            object o = cmd.ExecuteScalar();
            if (o != null && o != DBNull.Value) return o.ToString();
        }

        using (var cmd = new SqlCommand(
            "SELECT TOP 1 ID FROM FPERIODE WHERE EXERCICE_ID = @ex ORDER BY NUMERO", conn, tx))
        {
            cmd.Parameters.AddWithValue("@ex", exerciceId);
            object o = cmd.ExecuteScalar();
            if (o != null && o != DBNull.Value) return o.ToString();
        }

        DateTime dDebut, dFin;
        using (var cmd = new SqlCommand(
            "SELECT DATE_DEBUT, DATE_FIN FROM FEXERCICE WHERE ID = @id AND DELETION_AT IS NULL",
            conn, tx))
        {
            cmd.Parameters.AddWithValue("@id", exerciceId);
            using (var r = cmd.ExecuteReader())
            {
                if (!r.Read()) throw new Exception("Exercice introuvable.");
                dDebut = Convert.ToDateTime(r["DATE_DEBUT"]);
                dFin   = Convert.ToDateTime(r["DATE_FIN"]);
            }
        }

        string newId = Guid.NewGuid().ToString();
        using (var cmd = new SqlCommand(@"
            INSERT INTO FPERIODE
                (ID, EXERCICE_ID, NUMERO, LIBELLE, DATE_DEBUT, DATE_FIN, STATUT, CREATED_BY, CREATED_AT)
            VALUES (@id, @ex, 1, @lib, @dd, @df, 'OUVERTE', @u, GETDATE())", conn, tx))
        {
            cmd.Parameters.AddWithValue("@id",  newId);
            cmd.Parameters.AddWithValue("@ex",  exerciceId);
            cmd.Parameters.AddWithValue("@lib", "Période " + dDebut.Year);
            cmd.Parameters.AddWithValue("@dd",  dDebut);
            cmd.Parameters.AddWithValue("@df",  dFin);
            cmd.Parameters.AddWithValue("@u",   userId);
            cmd.ExecuteNonQuery();
        }

        return newId;
    }

    private string GetString(Dictionary<string, object> data, string key)
    { return data.ContainsKey(key) && data[key] != null ? data[key].ToString() : null; }
    private int GetInt(Dictionary<string, object> data, string key, int def)
    {
        int v;
        if (data.ContainsKey(key) && data[key] != null && int.TryParse(data[key].ToString(), out v)) return v;
        return def;
    }
    private decimal GetDecimal(Dictionary<string, object> data, string key, decimal def)
    {
        decimal v;
        if (data.ContainsKey(key) && data[key] != null &&
            decimal.TryParse(data[key].ToString(), System.Globalization.NumberStyles.Any,
                System.Globalization.CultureInfo.InvariantCulture, out v)) return v;
        return def;
    }
    private List<Dictionary<string, object>> GetObjectList(Dictionary<string, object> data, string key)
    {
        var result = new List<Dictionary<string, object>>();
        if (!data.ContainsKey(key) || data[key] == null) return result;
        var arr = data[key] as IList;
        if (arr == null) return result;
        foreach (var item in arr)
        {
            var dict = item as Dictionary<string, object>;
            if (dict != null) result.Add(dict);
        }
        return result;
    }

    public bool IsReusable { get { return false; } }
}

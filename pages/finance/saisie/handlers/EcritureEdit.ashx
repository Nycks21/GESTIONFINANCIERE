<%@ WebHandler Language="C#" Class="EcritureEdit" %>
using System;
using System.Collections;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class EcritureEdit : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json; charset=utf-8";
        ctx.Response.Charset = "utf-8";
        ctx.Response.ContentEncoding = System.Text.Encoding.UTF8;
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
            Guid tmp;
            if (string.IsNullOrEmpty(id) || !Guid.TryParse(id, out tmp))
            { ctx.Response.Write("{\"success\":false,\"message\":\"ID d'écriture invalide.\"}"); return; }

            string exerciceId       = GetString(data, "exerciceId");
            string periodeId        = GetString(data, "periodeId");
            string journalId        = GetString(data, "journalId");
            string monnaieId        = GetString(data, "monnaieId");
            decimal coursDevise     = GetDecimal(data, "coursDevise", 1m);
            string siteId           = GetString(data, "siteId");
            string numero           = (GetString(data, "numero") ?? "").Trim();
            string dateCmp          = GetString(data, "dateComptable");
            string datePiece        = GetString(data, "datePiece");
            string reference        = (GetString(data, "reference") ?? "").Trim();
            string referenceFacture = (GetString(data, "referenceFacture") ?? "").Trim();
            string dateFacture      = GetString(data, "dateFacture");
            string libelle          = (GetString(data, "libelle") ?? "").Trim();
            string statut           = (GetString(data, "statut") ?? "BROUILLON").Trim().ToUpperInvariant();
            string marche           = (GetString(data, "marche") ?? "").Trim();

            if (string.IsNullOrEmpty(exerciceId) || !Guid.TryParse(exerciceId, out tmp))
            { ctx.Response.Write("{\"success\":false,\"message\":\"Exercice requis.\"}"); return; }
            if (string.IsNullOrEmpty(journalId) || !Guid.TryParse(journalId, out tmp))
            { ctx.Response.Write("{\"success\":false,\"message\":\"Journal requis.\"}"); return; }
            if (string.IsNullOrEmpty(monnaieId) || !Guid.TryParse(monnaieId, out tmp))
            { ctx.Response.Write("{\"success\":false,\"message\":\"Devise requise.\"}"); return; }
            if (coursDevise <= 0)
            { ctx.Response.Write("{\"success\":false,\"message\":\"Cours de devise invalide.\"}"); return; }
            if (string.IsNullOrEmpty(numero))
            { ctx.Response.Write("{\"success\":false,\"message\":\"Numéro obligatoire.\"}"); return; }
            if (string.IsNullOrEmpty(libelle))
            { ctx.Response.Write("{\"success\":false,\"message\":\"Libellé obligatoire.\"}"); return; }

            Guid siteGuid = Guid.Empty;
            bool hasSite = !string.IsNullOrEmpty(siteId) && Guid.TryParse(siteId, out siteGuid);

            DateTime dtComptable;
            if (!DateTime.TryParse(dateCmp, out dtComptable))
            { ctx.Response.Write("{\"success\":false,\"message\":\"Date comptable invalide.\"}"); return; }
            if (!string.IsNullOrWhiteSpace(datePiece))
            {
                DateTime dtPiece;
                if (!DateTime.TryParse(datePiece, out dtPiece))
                { ctx.Response.Write("{\"success\":false,\"message\":\"Date de pièce invalide.\"}"); return; }
                if (dtPiece.Date > dtComptable.Date)
                {
                    ctx.Response.Write("{\"success\":false,\"code\":\"DATE_PIECE_AFTER_COMPTABLE\",\"message\":\"La date de pièce doit être antérieure ou égale à la date comptable.\"}");
                    return;
                }
            }

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
                decimal coursLigne    = GetDecimal(l, "coursDevise", coursDevise);
                string dateEcheanceRaw = GetString(l, "dateEcheance");
                DateTime dateEcheance;
                int categorieJournal  = GetInt(l, "categorieJournal", 1); // ⭐ Récupération de la catégorie

                if (debit < 0 || credit < 0 || montantDevise < 0
                    || (debit > 0 && credit > 0) || (debit == 0 && credit == 0))
                { ctx.Response.Write("{\"success\":false,\"message\":\"Montant invalide sur une ligne.\"}"); return; }
                if (categorieJournal != 1 && categorieJournal != 2)
                { ctx.Response.Write("{\"success\":false,\"message\":\"Catégorie de journal invalide.\"}"); return; }
                if (coursLigne <= 0)
                { ctx.Response.Write("{\"success\":false,\"message\":\"Cours de devise invalide sur une ligne.\"}"); return; }
                if (!string.IsNullOrEmpty(dateEcheanceRaw)
                    && !DateTime.TryParseExact(dateEcheanceRaw, "yyyy-MM-dd",
                        System.Globalization.CultureInfo.InvariantCulture,
                        System.Globalization.DateTimeStyles.None, out dateEcheance))
                { ctx.Response.Write("{\"success\":false,\"message\":\"Date d'échéance invalide.\"}"); return; }

                string sens = debit > 0 ? "D" : "C";
                decimal montant = debit > 0 ? debit : credit;

                totalD += debit;
                totalC += credit;
                if (sens == "D") totalDDevise += montantDevise;
                else             totalCDevise += montantDevise;

                var pl = new Dictionary<string, object>();
                pl["ID"]                = GetString(l, "id");
                pl["COMPTE_ID"]         = compteId;
                pl["COMPTE_PLAN_ORDER"] = GetInt(l, "comptePlanOrder", 0);
                pl["TIERS_ID"]          = null;
                string tiersStr = GetString(l, "tiersId");
                if (!string.IsNullOrEmpty(tiersStr) && Guid.TryParse(tiersStr, out tiersId))
                    pl["TIERS_ID"] = tiersId;
                pl["AUXILIAIRE"]         = GetString(l, "auxiliaire");
                pl["LIBELLE"]            = GetString(l, "libelle");
                pl["SENS"]               = sens;
                pl["MONTANT"]            = montant;
                pl["MONTANT_DEVISE"]     = montantDevise;
                pl["COURS_DEVISE"]       = coursLigne;
                pl["DATE_ECHEANCE"]      = string.IsNullOrEmpty(dateEcheanceRaw) ? null : (object)DateTime.ParseExact(
                    dateEcheanceRaw, "yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture);
                pl["CATEGORIE_JOURNAL"]  = categorieJournal; // ⭐ Ajout
                pl["MODE_REGULARISATION"] = GetString(l, "modeRegularisation");
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

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (var tx = conn.BeginTransaction())
                {
                    try
                    {
                        JournalAccountValidation.ValidatePlan1BankAccounts(
                            conn, tx, journalId, parsedLignes);

                        string periodeIdFinal = EnsurePeriodeFromExercice(conn, tx, exerciceId, dtComptable, userId);

                        // Unicité numéro journal/exercice (exclure l'ID courant)
                        using (var cmdChk = new SqlCommand(@"
                            SELECT COUNT(1) FROM FECRITURE
                            WHERE JOURNAL_ID = @j AND EXERCICE_ID = @e AND NUMERO = @n AND ID <> @id", conn, tx))
                        {
                            cmdChk.Parameters.AddWithValue("@j", journalId);
                            cmdChk.Parameters.AddWithValue("@e", exerciceId);
                            cmdChk.Parameters.AddWithValue("@n", numero);
                            cmdChk.Parameters.AddWithValue("@id", id);
                            if (Convert.ToInt32(cmdChk.ExecuteScalar()) > 0)
                                throw new Exception("Ce numéro d'écriture existe déjà pour ce journal/exercice.");
                        }

                        // Vérification du statut actuel
                        using (var cmdSt = new SqlCommand("SELECT STATUT FROM FECRITURE WHERE ID = @id", conn, tx))
                        {
                            cmdSt.Parameters.AddWithValue("@id", id);
                            object st = cmdSt.ExecuteScalar();
                            if (st == null) throw new Exception("Écriture introuvable.");
                            string curStatut = st.ToString();
                            if (curStatut == "COMPTABILISEE" || curStatut == "ANNULEE")
                                throw new Exception("Écriture non modifiable (statut " + curStatut + ").");
                        }

                        // ⭐ UPDATE ENTÊTE
                        using (var cmd = new SqlCommand(@"
                            UPDATE FECRITURE
                            SET EXERCICE_ID=@ex, PERIODE_ID=@pe, JOURNAL_ID=@j,
                                SITE_ID=@site, MONNAIE_ID=@m, MARCHE=@marche,
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
                            cmd.Parameters.AddWithValue("@marche", string.IsNullOrEmpty(marche) ? (object)DBNull.Value : marche);
                            cmd.Parameters.AddWithValue("@n", numero);
                            cmd.Parameters.AddWithValue("@dc", dtComptable);
                            cmd.Parameters.AddWithValue("@dp", string.IsNullOrEmpty(datePiece) ? (object)DBNull.Value : DateTime.Parse(datePiece));
                            cmd.Parameters.AddWithValue("@ref", string.IsNullOrEmpty(reference) ? (object)DBNull.Value : reference);
                            cmd.Parameters.AddWithValue("@refFact", string.IsNullOrEmpty(referenceFacture) ? (object)DBNull.Value : referenceFacture);
                            cmd.Parameters.AddWithValue("@dateFact", string.IsNullOrEmpty(dateFacture) ? (object)DBNull.Value : DateTime.Parse(dateFacture));
                            cmd.Parameters.AddWithValue("@lib", libelle);
                            cmd.Parameters.AddWithValue("@td", totalD);
                            cmd.Parameters.AddWithValue("@tc", totalC);
                            cmd.Parameters.AddWithValue("@st", statut);
                            cmd.Parameters.AddWithValue("@u", userId);
                            cmd.ExecuteNonQuery();
                        }

                        // ⭐ SUPPRESSION ANCIENNES LIGNES
                        using (var cmdDel = new SqlCommand("DELETE FROM FECRITURE_LIGNE WHERE ECRITURE_ID = @id", conn, tx))
                        {
                            cmdDel.Parameters.AddWithValue("@id", id);
                            cmdDel.ExecuteNonQuery();
                        }

                        // ⭐ INSERTION NOUVELLES LIGNES (avec CATEGORIE_JOURNAL)
                        int ordre = 1;
                        foreach (var l in parsedLignes)
                        {
                            using (var cmd = new SqlCommand(@"
                                INSERT INTO FECRITURE_LIGNE
                                    (ID, ECRITURE_ID, ORDRE, COMPTE_ID, COMPTE_PLAN_ORDER, TIERS_ID,
                                     AUXILIAIRE, LIBELLE, SENS, MONTANT, MONTANT_DEVISE, COURS_DEVISE,
                                     DATE_ECHEANCE, MODE_REGULARISATION, CATEGORIE_JOURNAL,
                                     PLAN1, PLAN2, PLAN3, PLAN4, PLAN5, PLAN6, PLAN7, PLAN8, PLAN9, PLAN10,
                                     SOURCE_FINANCEMENT, CREATED_BY, CREATED_AT)
                                VALUES
                                    (@id, @eid, @o, @cid, @cpo, @tid,
                                     @aux, @lib, @sens, @mnt, @mntdev, @cours,
                                     @echeance, @modeReg, @catj,
                                     @p1, @p2, @p3, @p4, @p5, @p6, @p7, @p8, @p9, @p10,
                                     @src, @u, GETDATE())", conn, tx))
                            {
                                cmd.Parameters.AddWithValue("@id", Guid.NewGuid().ToString());
                                cmd.Parameters.AddWithValue("@eid", id);
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
                                cmd.Parameters.AddWithValue("@cours", l["COURS_DEVISE"]);
                                cmd.Parameters.AddWithValue("@echeance", l["DATE_ECHEANCE"] ?? (object)DBNull.Value);
                                cmd.Parameters.AddWithValue("@modeReg", string.IsNullOrEmpty((string)l["MODE_REGULARISATION"]) ? (object)DBNull.Value : l["MODE_REGULARISATION"]);
                                cmd.Parameters.AddWithValue("@catj", l["CATEGORIE_JOURNAL"]); // ⭐ AJOUT
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

                        // Audit
                        try
                        {
                            string ip = ctx.Request.UserHostAddress ?? "";
                            using (var cmdLog = new SqlCommand(@"
                                INSERT INTO SECURITY_LOG (USER_ID, ACTION, DETAILS, IP_ADDRESS, CREATED_AT)
                                VALUES (@u, @a, @d, @ip, GETDATE())", conn, tx))
                            {
                                cmdLog.Parameters.AddWithValue("@u", userId);
                                cmdLog.Parameters.AddWithValue("@a", "ECRITURE_EDIT");
                                cmdLog.Parameters.AddWithValue("@d", numero + " - " + libelle);
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
                id = id,
                message = "Écriture modifiée avec succès."
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

    private string EnsurePeriodeFromExercice(SqlConnection conn, SqlTransaction tx, string exerciceId, DateTime dateComptable, int userId)
    {
        DateTime dDebut, dFin;
        using (var cmd = new SqlCommand(@"
            SELECT DATE_DEBUT, DATE_FIN FROM FEXERCICE
             WHERE ID = @id AND STATUT = 'OUVERT' AND DELETION_AT IS NULL", conn, tx))
        {
            cmd.Parameters.AddWithValue("@id", exerciceId);
            using (var r = cmd.ExecuteReader())
            {
                if (!r.Read()) throw new Exception("Exercice introuvable ou fermé.");
                dDebut = Convert.ToDateTime(r["DATE_DEBUT"]).Date;
                dFin   = Convert.ToDateTime(r["DATE_FIN"]).Date;
            }
        }

        if (dateComptable.Date < dDebut || dateComptable.Date > dFin)
            throw new Exception("La date comptable doit appartenir à l'exercice sélectionné.");

        using (var cmd = new SqlCommand(@"
            SELECT TOP 1 ID FROM FPERIODE
             WHERE EXERCICE_ID = @ex AND STATUT = 'OUVERTE'
               AND @d BETWEEN DATE_DEBUT AND DATE_FIN
             ORDER BY NUMERO", conn, tx))
        {
            cmd.Parameters.AddWithValue("@ex", exerciceId);
            cmd.Parameters.AddWithValue("@d",  dateComptable.Date);
            object o = cmd.ExecuteScalar();
            if (o != null && o != DBNull.Value) return o.ToString();
        }
        using (var cmd = new SqlCommand("SELECT COUNT(1) FROM FPERIODE WHERE EXERCICE_ID = @ex", conn, tx))
        {
            cmd.Parameters.AddWithValue("@ex", exerciceId);
            if (Convert.ToInt32(cmd.ExecuteScalar()) > 0)
                throw new Exception("Aucune période ouverte ne correspond à la date comptable.");
        }
        string newId = Guid.NewGuid().ToString();
        using (var cmd = new SqlCommand(@"
            INSERT INTO FPERIODE (ID, EXERCICE_ID, NUMERO, LIBELLE, DATE_DEBUT, DATE_FIN, STATUT, CREATED_BY, CREATED_AT)
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

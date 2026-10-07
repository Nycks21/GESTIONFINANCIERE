using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.UI;

public partial class index : Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        AuthHelper.VerifySession(this);
        LocalizationHelper.HandleLanguage();

        string action = Request.QueryString["action"];
        if (string.IsNullOrEmpty(action)) return;

        Response.Clear();
        Response.ContentType = "application/json";
        Response.Charset = "utf-8";
        Response.Cache.SetNoStore();

        try
        {
            switch (action)
            {
                case "kpi":         WriteKpi(); break;
                case "evolution":   WriteEvolution(); break;
                case "repartition": WriteRepartition(); break;
                case "activites":   WriteActivites(); break;
                default:
                    Response.Write("{\"success\":false,\"message\":\"Action inconnue\"}");
                    break;
            }
        }
        catch (Exception ex)
        {
            Response.StatusCode = 500;
            Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = false,
                message = ex.Message
            }));
        }
        Response.End();
    }

    // ============================================================
    // KPI — 4 indicateurs financiers + variation vs mois précédent
    // ============================================================
    private void WriteKpi()
    {
        var result = new Dictionary<string, object>();
        using (var conn = new SqlConnection(AuthHelper.ConnectionString))
        {
            conn.Open();

            // ---- Mois courant & mois précédent ----
            DateTime now        = DateTime.Today;
            DateTime debutCur   = new DateTime(now.Year, now.Month, 1);
            DateTime finCur     = debutCur.AddMonths(1).AddDays(-1);
            DateTime debutPrev  = debutCur.AddMonths(-1);
            DateTime finPrev    = debutCur.AddDays(-1);

            // ── SOLDE ACTUEL (classe 5) ──
            const string sqlSolde = @"
                SELECT ISNULL(SUM(L.DEBIT - L.CREDIT), 0)
                  FROM FECRITURE_LIGNE L
                  INNER JOIN FECRITURE      E  ON E.ID  = L.ECRITURE_ID
                  INNER JOIN FPLAN_ELEMENT PE  ON PE.ID = L.COMPTE_ID
                 WHERE E.STATUT IN ('VALIDEE','COMPTABILISEE')
                   AND PE.CODE LIKE '5%'";
            decimal soldeActuel = 0m;
            using (var cmd = new SqlCommand(sqlSolde, conn))
                soldeActuel = Convert.ToDecimal(cmd.ExecuteScalar());
            result["soldeActuel"] = soldeActuel;

            // ── ÉCRITURES DU MOIS ──
            const string sqlEcrM = @"
                SELECT COUNT(*) FROM FECRITURE
                 WHERE STATUT IN ('VALIDEE','COMPTABILISEE')
                   AND DATE_COMPTABLE BETWEEN @d1 AND @d2";
            int ecrCur = 0, ecrPrev = 0;
            using (var cmd = new SqlCommand(sqlEcrM, conn))
            {
                cmd.Parameters.AddWithValue("@d1", debutCur);
                cmd.Parameters.AddWithValue("@d2", finCur);
                ecrCur = Convert.ToInt32(cmd.ExecuteScalar());
            }
            using (var cmd = new SqlCommand(sqlEcrM, conn))
            {
                cmd.Parameters.AddWithValue("@d1", debutPrev);
                cmd.Parameters.AddWithValue("@d2", finPrev);
                ecrPrev = Convert.ToInt32(cmd.ExecuteScalar());
            }
            result["ecrituresMois"] = ecrCur;
            result["ecrituresVar"]  = Pct(ecrCur, ecrPrev);

            // ── ENTRÉES (TOTAL_DEBIT) mois courant & précédent ──
            const string sqlMvt = @"
                SELECT ISNULL(SUM(TOTAL_DEBIT),0)  AS E,
                       ISNULL(SUM(TOTAL_CREDIT),0) AS S
                  FROM FECRITURE
                 WHERE STATUT IN ('VALIDEE','COMPTABILISEE')
                   AND DATE_COMPTABLE BETWEEN @d1 AND @d2";
            decimal entCur = 0m, sortCur = 0m, entPrev = 0m, sortPrev = 0m;
            using (var cmd = new SqlCommand(sqlMvt, conn))
            {
                cmd.Parameters.AddWithValue("@d1", debutCur);
                cmd.Parameters.AddWithValue("@d2", finCur);
                using (var r = cmd.ExecuteReader())
                {
                    if (r.Read())
                    {
                        entCur  = Convert.ToDecimal(r["E"]);
                        sortCur = Convert.ToDecimal(r["S"]);
                    }
                    r.Close();
                }
            }
            using (var cmd = new SqlCommand(sqlMvt, conn))
            {
                cmd.Parameters.AddWithValue("@d1", debutPrev);
                cmd.Parameters.AddWithValue("@d2", finPrev);
                using (var r = cmd.ExecuteReader())
                {
                    if (r.Read())
                    {
                        entPrev  = Convert.ToDecimal(r["E"]);
                        sortPrev = Convert.ToDecimal(r["S"]);
                    }
                    r.Close();
                }
            }
            result["entreesTotales"] = entCur;
            result["entreesVar"]     = Pct(entCur, entPrev);
            result["sortiesTotales"] = sortCur;
            result["sortiesVar"]     = Pct(sortCur, sortPrev);
        }

        result["success"] = true;
        Response.Write(new JavaScriptSerializer().Serialize(result));
    }

    // ============================================================
    // ÉVOLUTION — entrées/sorties sur 12 mois
    // ============================================================
    private void WriteEvolution()
    {
        var labels  = new List<string> { "Jan","Fév","Mar","Avr","Mai","Jun","Jul","Aoû","Sep","Oct","Nov","Déc" };
        var entrees = new decimal[12];
        var sorties = new decimal[12];

        using (var conn = new SqlConnection(AuthHelper.ConnectionString))
        {
            conn.Open();
            const string sql = @"
                SELECT MONTH(DATE_COMPTABLE) AS M,
                       ISNULL(SUM(TOTAL_DEBIT),0)  AS E,
                       ISNULL(SUM(TOTAL_CREDIT),0) AS S
                  FROM FECRITURE
                 WHERE STATUT IN ('VALIDEE','COMPTABILISEE')
                   AND YEAR(DATE_COMPTABLE) = YEAR(GETDATE())
                 GROUP BY MONTH(DATE_COMPTABLE)";
            using (var cmd = new SqlCommand(sql, conn))
            using (var r = cmd.ExecuteReader())
            {
                while (r.Read())
                {
                    int m = Convert.ToInt32(r["M"]) - 1;
                    if (m >= 0 && m < 12)
                    {
                        entrees[m] = Convert.ToDecimal(r["E"]);
                        sorties[m] = Convert.ToDecimal(r["S"]);
                    }
                }
            }
        }
        Response.Write(new JavaScriptSerializer().Serialize(new
        {
            success = true, labels = labels, entrees = entrees, sorties = sorties
        }));
    }

    // ============================================================
    // RÉPARTITION — catégories de dépenses (classe 6, niveau 2)
    // ============================================================
    private void WriteRepartition()
    {
        var labels  = new List<string>();
        var valeurs = new List<decimal>();

        using (var conn = new SqlConnection(AuthHelper.ConnectionString))
        {
            conn.Open();
            const string sql = @"
                SELECT ISNULL(PE.LIBELLE,'Non classé') AS LIB,
                       ISNULL(SUM(L.DEBIT),0)          AS MONTANT
                  FROM FECRITURE_LIGNE L
                  INNER JOIN FECRITURE      E  ON E.ID  = L.ECRITURE_ID
                  INNER JOIN FPLAN_ELEMENT PE  ON PE.ID = L.COMPTE_ID
                 WHERE E.STATUT IN ('VALIDEE','COMPTABILISEE')
                   AND PE.CODE LIKE '6%'
                   AND MONTH(E.DATE_COMPTABLE) = MONTH(GETDATE())
                   AND YEAR(E.DATE_COMPTABLE)  = YEAR(GETDATE())
                 GROUP BY PE.LIBELLE
                 HAVING SUM(L.DEBIT) > 0
                 ORDER BY MONTANT DESC";
            using (var cmd = new SqlCommand(sql, conn))
            using (var r = cmd.ExecuteReader())
            {
                int i = 0;
                while (r.Read() && i < 5) // top 5
                {
                    labels.Add(r["LIB"].ToString());
                    valeurs.Add(Convert.ToDecimal(r["MONTANT"]));
                    i++;
                }
            }
        }
        Response.Write(new JavaScriptSerializer().Serialize(new
        {
            success = true, labels = labels, valeurs = valeurs
        }));
    }

    // ============================================================
    // ACTIVITÉS — dernières opérations multi-modules
    // ============================================================
    private void WriteActivites()
    {
        var list = new List<Dictionary<string, object>>();
        using (var conn = new SqlConnection(AuthHelper.ConnectionString))
        {
            conn.Open();

            // ---- Écritures comptables ----
            const string sqlE = @"
                SELECT TOP 5 'ECRITURE' AS TYPE,
                       E.LIBELLE       AS TITRE,
                       E.NUMERO        AS REF,
                       E.STATUT        AS STATUT,
                       E.CREATED_AT    AS DT,
                       J.LIBELLE       AS CTX
                  FROM FECRITURE E
                  INNER JOIN FJOURNAL J ON J.ID = E.JOURNAL_ID
                 WHERE E.DELETION_BY IS NULL OR E.DELETION_BY IS NULL
                 ORDER BY E.CREATED_AT DESC";
            // NB : FECRITURE n'a pas de DELETION_AT, on se contente de ORDER BY
            const string sqlE2 = @"
                SELECT TOP 5 'ECRITURE' AS TYPE,
                       E.LIBELLE       AS TITRE,
                       E.NUMERO        AS REF,
                       E.STATUT        AS STATUT,
                       E.CREATED_AT    AS DT,
                       J.LIBELLE       AS CTX
                  FROM FECRITURE E
                  INNER JOIN FJOURNAL J ON J.ID = E.JOURNAL_ID
                 ORDER BY E.CREATED_AT DESC";
            using (var cmd = new SqlCommand(sqlE2, conn))
            using (var r = cmd.ExecuteReader())
            {
                while (r.Read()) list.Add(Row(r));
            }

            // ---- Entrées de stock ----
            const string sqlEnt = @"
                SELECT TOP 5 'ENTREE' AS TYPE,
                       'Entrée de stock' AS TITRE,
                       S.NUMERO  AS REF,
                       S.STATUT  AS STATUT,
                       S.CREATED_AT AS DT,
                       ISNULL(F.NOM,'') AS CTX
                  FROM SENTREE S
                  LEFT JOIN SFOURNISSEUR F ON F.ID = S.FOURNISSEUR_ID
                 WHERE S.DELETION_AT IS NULL
                 ORDER BY S.CREATED_AT DESC";
            using (var cmd = new SqlCommand(sqlEnt, conn))
            using (var r = cmd.ExecuteReader())
            {
                while (r.Read()) list.Add(Row(r));
            }

            // ---- Sorties de stock ----
            const string sqlSort = @"
                SELECT TOP 5 'SORTIE' AS TYPE,
                       'Sortie de stock' AS TITRE,
                       S.NUMERO AS REF,
                       S.STATUT AS STATUT,
                       S.CREATED_AT AS DT,
                       ISNULL(S.DESTINATION,'') AS CTX
                  FROM SSORTIE S
                 WHERE S.DELETION_AT IS NULL
                 ORDER BY S.CREATED_AT DESC";
            using (var cmd = new SqlCommand(sqlSort, conn))
            using (var r = cmd.ExecuteReader())
            {
                while (r.Read()) list.Add(Row(r));
            }

            // ---- Rapprochements bancaires ----
            const string sqlR = @"
                SELECT TOP 5 'RAPPRO' AS TYPE,
                       'Rapprochement bancaire' AS TITRE,
                       RV.NUMERO_RELEVE AS REF,
                       R.STATUT AS STATUT,
                       R.CREATED_AT AS DT,
                       J.LIBELLE AS CTX
                  FROM FRECONCILIATION R
                  INNER JOIN FRELEVE_BANCAIRE RV ON RV.ID = R.RELEVE_ID
                  INNER JOIN FJOURNAL          J  ON J.ID  = RV.JOURNAL_ID
                 ORDER BY R.CREATED_AT DESC";
            using (var cmd = new SqlCommand(sqlR, conn))
            using (var r = cmd.ExecuteReader())
            {
                while (r.Read()) list.Add(Row(r));
            }
        }

        // Trier par date desc et prendre les 5 premiers
        list.Sort((a, b) => Convert.ToDateTime(b["dt"]).CompareTo(Convert.ToDateTime(a["dt"])));
        if (list.Count > 5) list = list.GetRange(0, 5);

        Response.Write(new JavaScriptSerializer().Serialize(new { success = true, data = list }));
    }

    // ============================================================
    // Helpers
    // ============================================================
    private static Dictionary<string, object> Row(SqlDataReader r)
    {
        return new Dictionary<string, object>
        {
            { "type",   r["TYPE"].ToString() },
            { "titre",  r["TITRE"].ToString() },
            { "ref",    r["REF"]    == DBNull.Value ? "" : r["REF"].ToString() },
            { "statut", r["STATUT"] == DBNull.Value ? "" : r["STATUT"].ToString() },
            { "ctx",    r["CTX"]    == DBNull.Value ? "" : r["CTX"].ToString() },
            { "dt",     Convert.ToDateTime(r["DT"]).ToString("o") }
        };
    }

    private static decimal Pct(decimal cur, decimal prev)
    {
        if (prev == 0m) return cur > 0m ? 100m : 0m;
        return Math.Round((cur - prev) / prev * 100m, 1);
    }
}

using System;
using System.Collections.Generic;
using System.Data.SqlClient;

public static class JournalAccountValidation
{
    public static void ValidatePlan1BankAccounts(
        SqlConnection conn,
        SqlTransaction tx,
        string journalId,
        IList<Dictionary<string, object>> lignes)
    {
        Guid? linkedPlan1Id = null;
        using (var cmd = new SqlCommand(@"
            SELECT PLAN_ORDER, COMPTE_BANQUE_ID
            FROM FJOURNAL
            WHERE ID = @journalId", conn, tx))
        {
            cmd.Parameters.AddWithValue("@journalId", journalId);
            using (var reader = cmd.ExecuteReader())
            {
                if (!reader.Read())
                    throw new InvalidOperationException("Journal introuvable.");

                if (reader["PLAN_ORDER"] != DBNull.Value
                    && Convert.ToInt32(reader["PLAN_ORDER"]) == 1
                    && reader["COMPTE_BANQUE_ID"] != DBNull.Value)
                {
                    Guid accountId;
                    if (Guid.TryParse(reader["COMPTE_BANQUE_ID"].ToString(), out accountId))
                        linkedPlan1Id = accountId;
                }
            }
        }

        var plan1Ids = new HashSet<Guid>();
        foreach (var ligne in lignes)
        {
            object value;
            Guid accountId;
            if (ligne.TryGetValue("PLAN1", out value)
                && value != null
                && Guid.TryParse(value.ToString(), out accountId))
            {
                plan1Ids.Add(accountId);
            }
        }
        if (plan1Ids.Count == 0) return;

        var plan1Codes = new Dictionary<Guid, string>();
        var ids = new List<Guid>(plan1Ids);
        const int batchSize = 1000;
        for (int offset = 0; offset < ids.Count; offset += batchSize)
        {
            int count = Math.Min(batchSize, ids.Count - offset);
            var parameterNames = new string[count];
            using (var cmd = new SqlCommand())
            {
                cmd.Connection = conn;
                cmd.Transaction = tx;
                for (int i = 0; i < count; i++)
                {
                    parameterNames[i] = "@plan1_" + i;
                    cmd.Parameters.AddWithValue(parameterNames[i], ids[offset + i]);
                }

                cmd.CommandText = @"
                    SELECT ID, CODE
                    FROM PLAN1
                    WHERE ID IN (" + string.Join(",", parameterNames) + ")";
                using (var reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        plan1Codes[(Guid)reader["ID"]] =
                            reader["CODE"] == DBNull.Value ? "" : reader["CODE"].ToString();
                    }
                }
            }
        }

        foreach (var ligne in lignes)
        {
            object value;
            Guid accountId;
            string accountCode;
            if (!ligne.TryGetValue("PLAN1", out value)
                || value == null
                || !Guid.TryParse(value.ToString(), out accountId)
                || !plan1Codes.TryGetValue(accountId, out accountCode)
                || !accountCode.TrimStart().StartsWith("5", StringComparison.Ordinal))
            {
                continue;
            }

            if (!linkedPlan1Id.HasValue || linkedPlan1Id.Value != accountId)
            {
                throw new InvalidOperationException(
                    "Le compte bancaire PLAN1 doit être celui rattaché au journal.");
            }
        }
    }
}

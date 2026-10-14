using System;

/// <summary>
/// Helper : traduction ORDRE (1..10) → nom de table PLANx
/// Centralisé : tout le code passe par ici, jamais de nom de table ad-hoc.
/// </summary>
public static class AuthHelperPlan
{
    /// <summary>
    /// Retourne "PLAN1".."PLAN10" pour un ordre valide.
    /// Lève une exception si l'ordre n'est pas entre 1 et 10.
    /// </summary>
    public static string GetPlanTableName(int ordre)
    {
        if (ordre < 1 || ordre > 10)
            throw new ArgumentException("Ordre du plan invalide (1..10). Valeur reçue : " + ordre);

        return "PLAN" + ordre.ToString();
    }

    /// <summary>
    /// Tente de traduire sans lever d'exception.
    /// </summary>
    public static bool TryGetPlanTableName(int ordre, out string tableName)
    {
        tableName = null;
        if (ordre < 1 || ordre > 10) return false;
        tableName = "PLAN" + ordre.ToString();
        return true;
    }
}

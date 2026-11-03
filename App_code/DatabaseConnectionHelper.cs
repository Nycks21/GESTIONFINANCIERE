using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Web;
using System.Web.Caching;

public enum DatabaseConnectionStatus
{
    Connected,
    MissingConfiguration,
    InvalidConfiguration,
    Unavailable,
    IncompatibleSchema
}

public sealed class DatabaseHealth
{
    public DatabaseConnectionStatus Status { get; private set; }

    public DatabaseHealth(DatabaseConnectionStatus status)
    {
        Status = status;
    }

    public bool IsConnected
    {
        get { return Status == DatabaseConnectionStatus.Connected; }
    }
}

public static class DatabaseConnectionHelper
{
    private static readonly object HealthLock = new object();
    private static readonly string[] RequiredTables = new[]
    {
        "USERS", "USERROLE", "FSITE", "FMONNAIE", "FEXERCICE",
        "FJOURNAL", "FECRITURE", "FECRITURE_LIGNE", "MARTICLE", "SSTOCK"
    };

    public static string ConnectionString
    {
        get
        {
            ConnectionStringSettings setting = ConfigurationManager.ConnectionStrings["MaConnexion"];
            return setting == null ? String.Empty : setting.ConnectionString;
        }
    }

    public static string MasterConnectionString
    {
        get
        {
            ConnectionStringSettings masterSetting =
                ConfigurationManager.ConnectionStrings["MasterConnection"];
            if (masterSetting != null && !String.IsNullOrWhiteSpace(masterSetting.ConnectionString))
                return masterSetting.ConnectionString;

            string connectionString = ConnectionString;
            if (String.IsNullOrWhiteSpace(connectionString))
                return String.Empty;
            SqlConnectionStringBuilder builder = new SqlConnectionStringBuilder(connectionString);
            builder.InitialCatalog = "master";
            return builder.ConnectionString;
        }
    }

    public static DatabaseHealth CheckCurrentConnection()
    {
        string connectionString = ConnectionString;
        if (String.IsNullOrWhiteSpace(connectionString))
            return new DatabaseHealth(DatabaseConnectionStatus.MissingConfiguration);

        try
        {
            SqlConnectionStringBuilder builder = new SqlConnectionStringBuilder(connectionString);
            if (String.IsNullOrWhiteSpace(builder.DataSource) ||
                String.IsNullOrWhiteSpace(builder.InitialCatalog))
            {
                return new DatabaseHealth(DatabaseConnectionStatus.InvalidConfiguration);
            }

            builder.ConnectTimeout = builder.ConnectTimeout == 0
                ? 5
                : Math.Min(builder.ConnectTimeout, 5);
            using (SqlConnection connection = new SqlConnection(builder.ConnectionString))
            {
                connection.Open();
                if (!HasRequiredSchema(connection))
                    return new DatabaseHealth(DatabaseConnectionStatus.IncompatibleSchema);
            }
            return new DatabaseHealth(DatabaseConnectionStatus.Connected);
        }
        catch (ArgumentException)
        {
            return new DatabaseHealth(DatabaseConnectionStatus.InvalidConfiguration);
        }
        catch (InvalidOperationException)
        {
            return new DatabaseHealth(DatabaseConnectionStatus.InvalidConfiguration);
        }
        catch (SqlException exception)
        {
            return IsConnectionFailure(exception)
                ? new DatabaseHealth(DatabaseConnectionStatus.Unavailable)
                : new DatabaseHealth(DatabaseConnectionStatus.Connected);
        }
    }

    public static DatabaseHealth GetCachedHealth()
    {
        HttpContext context = HttpContext.Current;
        if (context == null)
            return CheckCurrentConnection();

        const string cacheKey = "GESTIONFINANCIERE_DATABASE_HEALTH";
        DatabaseHealth health = context.Cache[cacheKey] as DatabaseHealth;
        if (health != null)
            return health;

        lock (HealthLock)
        {
            health = context.Cache[cacheKey] as DatabaseHealth;
            if (health == null)
            {
                health = CheckCurrentConnection();
                context.Cache.Insert(cacheKey, health, null, DateTime.UtcNow.AddSeconds(15),
                    Cache.NoSlidingExpiration);
            }
        }
        return health;
    }

    public static void InvalidateHealthCache()
    {
        HttpContext context = HttpContext.Current;
        if (context != null)
            context.Cache.Remove("GESTIONFINANCIERE_DATABASE_HEALTH");
    }

    public static bool HasRequiredSchema(SqlConnection connection)
    {
        const string sql = @"
SELECT COUNT(*)
FROM sys.tables
WHERE schema_id = SCHEMA_ID('dbo')
  AND name IN (@t0, @t1, @t2, @t3, @t4, @t5, @t6, @t7, @t8, @t9);";

        using (SqlCommand command = new SqlCommand(sql, connection))
        {
            command.CommandTimeout = 5;
            for (int i = 0; i < RequiredTables.Length; i++)
                command.Parameters.Add("@t" + i, SqlDbType.NVarChar, 128).Value = RequiredTables[i];

            return Convert.ToInt32(command.ExecuteScalar()) == RequiredTables.Length;
        }
    }

    public static bool IsConnectionFailure(Exception exception)
    {
        while (exception != null)
        {
            SqlException sqlException = exception as SqlException;
            if (sqlException != null)
            {
                foreach (SqlError error in sqlException.Errors)
                {
                    switch (error.Number)
                    {
                        case -2:
                        case -1:
                        case 2:
                        case 40:
                        case 53:
                        case 64:
                        case 121:
                        case 233:
                        case 258:
                        case 4060:
                        case 18456:
                        case 10053:
                        case 10054:
                        case 10060:
                        case 10061:
                        case 11001:
                        case 10928:
                        case 10929:
                        case 40197:
                        case 40501:
                            return true;
                    }
                }
            }
            exception = exception.InnerException;
        }
        return false;
    }
}

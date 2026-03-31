// Feature: modernization-testing-framework, Property 6: Stage detector correctly identifies modernization stage
// Validates: Requirements 8.2, 8.3, 8.4

using FsCheck;
using FsCheck.Xunit;
using LoanProcessing.Web.Validation;
using LoanProcessing.Web.Validation.Models;
using Xunit;

namespace ModernizationTests;

/// <summary>
/// Property 6: Stage detector correctly identifies modernization stage.
/// 
/// Since StageDetector.Detect() checks the ACTUAL runtime version via Environment.Version
/// and ACTUAL environment variables, we test what we can deterministically verify:
///   - SQL Server connection strings → always PreModernization
///   - PostgreSQL connection strings → NOT PreModernization (we're on .NET 10, so PostModule2)
///   - Null or empty connection strings → PreModernization (default)
///   - The detector never throws for any input
/// </summary>
public class StageDetectorTests
{
    private readonly StageDetector _detector = new StageDetector();

    /// <summary>
    /// SQL Server connection strings (containing "Server=" or "Data Source=" but NOT "Host=")
    /// always produce PreModernization.
    /// </summary>
    [Property(MaxTest = 100)]
    public Property SqlServerConnectionStrings_ReturnPreModernization()
    {
        var serverNameArb = Arb.From(
            Gen.Elements("localhost", "myserver", "db.example.com", "192.168.1.1", "(local)", ".\\SQLEXPRESS")
        );
        var databaseNameArb = Arb.From(
            Gen.Elements("LoanProcessing", "TestDB", "MyApp", "Production")
        );
        var usePrefixArb = Arb.From(Gen.Elements("Server=", "Data Source="));

        return Prop.ForAll(serverNameArb, databaseNameArb, usePrefixArb,
            (server, database, prefix) =>
            {
                var connectionString = $"{prefix}{server};Database={database};Trusted_Connection=True;";
                var result = _detector.Detect(connectionString);
                return result == ModernizationStage.PreModernization;
            });
    }

    /// <summary>
    /// PostgreSQL connection strings (containing "Host=") on the current runtime (.NET 10+)
    /// should NOT return PreModernization. Since we're on .NET 10 and likely not in a container,
    /// the result should be PostModule2.
    /// </summary>
    [Property(MaxTest = 100)]
    public Property PostgreSqlConnectionStrings_ReturnNotPreModernization()
    {
        var hostArb = Arb.From(
            Gen.Elements("localhost", "mydb.cluster.us-east-1.rds.amazonaws.com", "192.168.1.50", "aurora-pg.example.com")
        );
        var portArb = Arb.From(Gen.Choose(1024, 65535));
        var databaseArb = Arb.From(
            Gen.Elements("loanprocessing", "testdb", "myapp")
        );

        return Prop.ForAll(hostArb, portArb, databaseArb,
            (host, port, database) =>
            {
                var connectionString = $"Host={host};Port={port};Database={database};Username=appuser;Password=secret;";
                var result = _detector.Detect(connectionString);
                return result != ModernizationStage.PreModernization;
            });
    }

    /// <summary>
    /// PostgreSQL connection strings on .NET 10 without DOTNET_RUNNING_IN_CONTAINER
    /// should return PostModule2 specifically.
    /// </summary>
    [Property(MaxTest = 100)]
    public Property PostgreSqlConnectionStrings_OnDotNet10_ReturnPostModule2()
    {
        var hostArb = Arb.From(
            Gen.Elements("localhost", "pg-server", "db.internal", "10.0.0.5")
        );
        var databaseArb = Arb.From(
            Gen.Elements("loanprocessing", "appdb", "workshop")
        );

        return Prop.ForAll(hostArb, databaseArb,
            (host, database) =>
            {
                // Only assert PostModule2 if we're sure the container env var is not set
                var containerVar = Environment.GetEnvironmentVariable("DOTNET_RUNNING_IN_CONTAINER");
                bool inContainer = !string.IsNullOrEmpty(containerVar) &&
                    (containerVar.Equals("true", StringComparison.OrdinalIgnoreCase) || containerVar == "1");

                var connectionString = $"Host={host};Database={database};Username=user;Password=pass;";
                var result = _detector.Detect(connectionString);

                if (inContainer)
                    return result == ModernizationStage.PostModule3;
                else
                    return result == ModernizationStage.PostModule2;
            });
    }

    /// <summary>
    /// Null or empty connection strings always return PreModernization (default/fallback).
    /// </summary>
    [Property(MaxTest = 100)]
    public Property NullOrEmptyConnectionStrings_ReturnPreModernization()
    {
        var emptyStringArb = Arb.From(
            Gen.Elements<string?>(null, "", " ", "  ", "\t", "\n")
        );

        return Prop.ForAll(emptyStringArb, input =>
        {
            var result = _detector.Detect(input!);
            return result == ModernizationStage.PreModernization;
        });
    }

    /// <summary>
    /// The detector never throws — it always returns a valid ModernizationStage for any input.
    /// </summary>
    [Property(MaxTest = 100)]
    public Property Detect_NeverThrows_ForAnyInput()
    {
        return Prop.ForAll(Arb.From<string>(), input =>
        {
            var result = _detector.Detect(input);
            return Enum.IsDefined(typeof(ModernizationStage), result);
        });
    }
}

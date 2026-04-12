using System;
using Xunit;
using LoanProcessing.Web.Validation;
using LoanProcessing.Web.Validation.Models;

namespace LoanProcessing.Tests
{
    /// <summary>
    /// Example-based unit tests for StageDetector.Detect().
    ///
    /// Runtime note: These tests run on the actual .NET runtime of the test host.
    /// On .NET Framework 4.7.2, Environment.Version.Major == 4, so SQL Server
    /// connection strings return PreModernization. On .NET 10+, the same SQL Server
    /// connection strings would return PostDotNet10 instead.
    /// </summary>
    public class StageDetectorTests
    {
        private readonly StageDetector _detector = new StageDetector();

        // Determine expected SQL Server stage based on the current runtime.
        // On .NET 10+ → PostDotNet10; on .NET Fx 4.x → PreModernization.
        private static ModernizationStage ExpectedSqlServerStage =>
            Environment.Version.Major >= 10
                ? ModernizationStage.PostDotNet10
                : ModernizationStage.PreModernization;

        #region Empty / Null connection strings

        [Fact]
        public void Detect_NullConnectionString_ReturnsPreModernization()
        {
            var result = _detector.Detect(null);
            Assert.Equal(ModernizationStage.PreModernization, result);
        }

        [Fact]
        public void Detect_EmptyConnectionString_ReturnsPreModernization()
        {
            var result = _detector.Detect(string.Empty);
            Assert.Equal(ModernizationStage.PreModernization, result);
        }

        [Fact]
        public void Detect_WhitespaceConnectionString_ReturnsPreModernization()
        {
            var result = _detector.Detect("   ");
            Assert.Equal(ModernizationStage.PreModernization, result);
        }

        #endregion

        #region SQL Server connection strings

        /// <summary>
        /// SQL Server connection string returns the stage appropriate for the
        /// current runtime: PostDotNet10 on .NET 10+, PreModernization on .NET Fx.
        /// </summary>
        [Fact]
        public void Detect_SqlServerConnectionString_ReturnsExpectedStageForRuntime()
        {
            var connStr = "Server=myserver.rds.amazonaws.com;Database=LoanProcessing;User Id=admin;Password=secret;";
            var result = _detector.Detect(connStr);
            Assert.Equal(ExpectedSqlServerStage, result);
        }

        /// <summary>
        /// On .NET Fx 4.x, SQL Server with CreditEvaluationCalculator present still
        /// returns PreModernization (the "Post-SP-Extraction" distinction is display-only).
        /// On .NET 10+, it returns PostDotNet10 regardless of CreditEvaluationCalculator.
        /// </summary>
        [Fact]
        public void Detect_SqlServerWithCreditEvaluationCalculator_ReturnsExpectedStageForRuntime()
        {
            // CreditEvaluationCalculator exists in the referenced LoanProcessing.Web assembly.
            // On .NET Fx this is PreModernization with a "Post-SP-Extraction" display label.
            // On .NET 10+ this is PostDotNet10 (the calculator check only affects the label,
            // not the enum value, and the .NET 10 branch takes priority).
            var connStr = "Server=myserver.rds.amazonaws.com;Database=LoanProcessing;User Id=admin;Password=secret;";
            var result = _detector.Detect(connStr);
            Assert.Equal(ExpectedSqlServerStage, result);
        }

        [Fact]
        public void Detect_SqlServerWithTrustServerCertificate_ReturnsExpectedStageForRuntime()
        {
            var connStr = "Server=myserver.rds.amazonaws.com;Database=LoanProcessing;User Id=admin;Password=secret;TrustServerCertificate=True;Encrypt=True;";
            var result = _detector.Detect(connStr);
            Assert.Equal(ExpectedSqlServerStage, result);
        }

        #endregion

        #region PostgreSQL connection strings

        /// <summary>
        /// PostgreSQL on .NET Fx 4.x returns PostModule1.
        /// PostgreSQL on .NET 8+ returns PostModule2 (or PostModule3 if in a container).
        /// </summary>
        [Fact]
        public void Detect_PostgreSQLConnectionString_ReturnsExpectedStageForRuntime()
        {
            var connStr = "Host=mypostgres.rds.amazonaws.com;Database=LoanProcessing;Username=admin;Password=secret;";
            var result = _detector.Detect(connStr);

            if (Environment.Version.Major >= 8)
            {
                // .NET 8+ without container → PostModule2
                Assert.Equal(ModernizationStage.PostModule2, result);
            }
            else
            {
                // .NET Fx 4.x → PostModule1
                Assert.Equal(ModernizationStage.PostModule1, result);
            }
        }

        [Fact]
        public void Detect_NpgsqlConnectionString_ReturnsExpectedStageForRuntime()
        {
            // "Npgsql" keyword also triggers PostgreSQL detection
            var connStr = "Server=mypostgres.rds.amazonaws.com;Database=LoanProcessing;Npgsql;";
            var result = _detector.Detect(connStr);

            if (Environment.Version.Major >= 8)
            {
                Assert.Equal(ModernizationStage.PostModule2, result);
            }
            else
            {
                Assert.Equal(ModernizationStage.PostModule1, result);
            }
        }

        #endregion
    }
}

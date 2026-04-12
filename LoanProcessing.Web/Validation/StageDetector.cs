using System;
using LoanProcessing.Web.Validation.Models;

namespace LoanProcessing.Web.Validation
{
    /// <summary>
    /// Detects the current modernization stage by inspecting the app's own
    /// connection string, runtime version, and environment variables.
    /// All detection happens from inside the process — no external probing.
    /// </summary>
    public class StageDetector
    {
        /// <summary>
        /// Detects the current modernization stage.
        /// Returns PreModernization if detection is inconclusive.
        /// This method never throws.
        /// </summary>
        public ModernizationStage Detect(string connectionString)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(connectionString))
                {
                    return ModernizationStage.PreModernization;
                }

                bool isPostgreSQL = IsPostgreSQLConnection(connectionString);

                if (!isPostgreSQL)
                {
                    // SQL Server connection string — check .NET version
                    if (IsDotNet10OrLater())
                    {
                        // SQL Server + .NET 10+ → PostDotNet10
                        return ModernizationStage.PostDotNet10;
                    }

                    // SQL Server + .NET Framework 4.x → PreModernization
                    return ModernizationStage.PreModernization;
                }

                // PostgreSQL detected — now check .NET version
                bool isDotNet8OrLater = IsDotNet8OrLater();

                if (!isDotNet8OrLater)
                {
                    // PostgreSQL + .NET Framework 4.x → Post-Module-1
                    return ModernizationStage.PostModule1;
                }

                // PostgreSQL + .NET 8+ — check for container
                bool isContainer = IsRunningInContainer();

                if (isContainer)
                {
                    // PostgreSQL + .NET 8+ + container → Post-Module-3
                    return ModernizationStage.PostModule3;
                }

                // PostgreSQL + .NET 8+ without container → Post-Module-2
                return ModernizationStage.PostModule2;
            }
            catch
            {
                // If anything goes wrong, default to PreModernization
                return ModernizationStage.PreModernization;
            }
        }

        /// <summary>
        /// Checks if the connection string indicates a PostgreSQL database.
        /// Looks for "Host=" or "Npgsql" in the connection string.
        /// </summary>
        private static bool IsPostgreSQLConnection(string connectionString)
        {
            if (string.IsNullOrWhiteSpace(connectionString))
            {
                return false;
            }

            return connectionString.IndexOf("Host=", StringComparison.OrdinalIgnoreCase) >= 0
                || connectionString.IndexOf("Npgsql", StringComparison.OrdinalIgnoreCase) >= 0;
        }

        /// <summary>
        /// Checks if the runtime is .NET 10 or later.
        /// Uses Environment.Version first, then falls back to
        /// RuntimeInformation.FrameworkDescription if available.
        /// On .NET Framework 4.x, Environment.Version.Major returns 4.
        /// On .NET 10+, Environment.Version.Major returns 10+.
        /// </summary>
        private static bool IsDotNet10OrLater()
        {
            var version = Environment.Version;
            if (version.Major >= 10)
            {
                return true;
            }

            try
            {
                var frameworkDescription = GetFrameworkDescription();
                if (!string.IsNullOrEmpty(frameworkDescription))
                {
                    if (frameworkDescription.StartsWith(".NET ", StringComparison.OrdinalIgnoreCase)
                        && !frameworkDescription.StartsWith(".NET Framework", StringComparison.OrdinalIgnoreCase))
                    {
                        var parts = frameworkDescription.Substring(5).Trim().Split('.');
                        int major;
                        if (parts.Length > 0 && int.TryParse(parts[0], out major))
                        {
                            return major >= 10;
                        }
                    }
                }
            }
            catch
            {
                // RuntimeInformation not available — that's fine
            }

            return false;
        }

        /// <summary>
        /// Checks if the runtime is .NET 8 or later.
        /// Uses Environment.Version first, then falls back to
        /// RuntimeInformation.FrameworkDescription if available.
        /// On .NET Framework 4.x, Environment.Version.Major returns 4.
        /// On .NET 8+, Environment.Version.Major returns 8+.
        /// </summary>
        private static bool IsDotNet8OrLater()
        {
            // Environment.Version on .NET Framework 4.7.2 returns 4.x
            // On .NET 8, it returns 8.x
            var version = Environment.Version;
            if (version.Major >= 8)
            {
                return true;
            }

            // Try RuntimeInformation.FrameworkDescription as a fallback.
            // This may not be available on all .NET Framework 4.x configurations,
            // so we use reflection to avoid hard compile-time dependency issues.
            try
            {
                var frameworkDescription = GetFrameworkDescription();
                if (!string.IsNullOrEmpty(frameworkDescription))
                {
                    // .NET 8 description looks like ".NET 8.0.x"
                    // .NET Framework looks like ".NET Framework 4.7.2..."
                    if (frameworkDescription.StartsWith(".NET ", StringComparison.OrdinalIgnoreCase)
                        && !frameworkDescription.StartsWith(".NET Framework", StringComparison.OrdinalIgnoreCase))
                    {
                        // Parse version from ".NET 8.0.x" format
                        var parts = frameworkDescription.Substring(5).Trim().Split('.');
                        int major;
                        if (parts.Length > 0 && int.TryParse(parts[0], out major))
                        {
                            return major >= 8;
                        }
                    }
                }
            }
            catch
            {
                // RuntimeInformation not available — that's fine
            }

            return false;
        }

        /// <summary>
        /// Attempts to get RuntimeInformation.FrameworkDescription via reflection.
        /// Returns null if the type or property is not available.
        /// </summary>
        private static string GetFrameworkDescription()
        {
            try
            {
                var type = Type.GetType(
                    "System.Runtime.InteropServices.RuntimeInformation, System.Runtime.InteropServices.RuntimeInformation",
                    throwOnError: false);

                if (type == null)
                {
                    // Try without assembly qualification (available in .NET 8+)
                    type = Type.GetType("System.Runtime.InteropServices.RuntimeInformation");
                }

                if (type != null)
                {
                    var prop = type.GetProperty("FrameworkDescription",
                        System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Static);
                    if (prop != null)
                    {
                        return prop.GetValue(null) as string;
                    }
                }
            }
            catch
            {
                // Swallow — not available
            }

            return null;
        }

        /// <summary>
        /// Checks if the application is running inside a container
        /// by inspecting the DOTNET_RUNNING_IN_CONTAINER environment variable.
        /// </summary>
        private static bool IsRunningInContainer()
        {
            try
            {
                var value = Environment.GetEnvironmentVariable("DOTNET_RUNNING_IN_CONTAINER");
                if (!string.IsNullOrEmpty(value))
                {
                    return string.Equals(value, "true", StringComparison.OrdinalIgnoreCase)
                        || value == "1";
                }
            }
            catch
            {
                // Environment variable access failed — not in container
            }

            return false;
        }
    }
}

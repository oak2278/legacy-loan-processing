# Module 2 Post-Transform Fix Guide

Known issues that surface after AWS Transform converts the codebase from .NET Framework 4.7.2 to .NET 10. These require manual intervention after every transformation run.

## 1. Duplicate Constructors in Controllers

**Symptom:** `System.InvalidOperationException: Multiple constructors accepting all given argument types have been found`

**Cause:** AWS Transform preserves both the legacy parameterless constructor (which uses `ConfigurationManager` to manually `new` up dependencies) and the DI constructor. ASP.NET Core's DI container can't choose between them.

**Affected files:** All controllers — `CustomerController.cs`, `LoanController.cs`, `ReportController.cs`, `InterestRateController.cs`

**Fix:** Remove the parameterless constructor from each controller. Keep only the constructor that accepts injected services.

**Pre-flight check:**
```bash
grep -rn "ConfigurationManager" LoanProcessing.Web/Controllers/ --include="*.cs"
```

## 2. Duplicate Constructors in Repositories

**Symptom:** `System.NullReferenceException` at repository `.ctor()` — DI resolves the parameterless constructor which calls `ConfigurationManager.ConnectionStrings` (returns null on ASP.NET Core).

**Cause:** Same as #1 but one layer down. Repositories have parameterless constructors that read connection strings via `ConfigurationManager`.

**Affected files:** `CustomerRepository.cs`, `LoanApplicationRepository.cs`, `LoanDecisionRepository.cs`, `PaymentScheduleRepository.cs`, `ReportRepository.cs`

**Fix:**
1. Remove parameterless constructors from all repositories
2. Update `Program.cs` DI registrations from simple type mappings to factory lambdas:

```csharp
var connectionString = builder.Configuration.GetConnectionString("LoanProcessingConnection");
builder.Services.AddScoped<ICustomerRepository>(sp => new CustomerRepository(connectionString!));
// ... repeat for all repositories
```

**Pre-flight check:**
```bash
grep -rn "ConfigurationManager" LoanProcessing.Web/Data/ --include="*.cs"
```

## 3. ValidationController Using ConfigurationManager

**Symptom:** `/Validation` returns HTTP 500 — `System.ArgumentException: Connection string cannot be null or empty`

**Cause:** `ValidationController` has a parameterless constructor that reads the connection string via `ConfigurationManager`.

**Affected file:** `LoanProcessing.Web/Validation/ValidationController.cs`

**Fix:** Replace the parameterless constructor with one that accepts `IConfiguration`:

```csharp
public ValidationController(IConfiguration configuration)
{
    var connectionString = configuration.GetConnectionString("LoanProcessingConnection");
    _validationService = new ValidationService(connectionString);
}
```

## 4. CreditEvaluationTests Using Legacy SqlClient

**Symptom:** Shadow comparison tests fail at runtime with connection or type errors.

**Cause:** `CreditEvaluationTests` has a private `GetConnectionString()` method that uses `ConfigurationManager`, and uses `System.Data.SqlClient` (the old namespace) instead of `Microsoft.Data.SqlClient`.

**Affected file:** `LoanProcessing.Web/Validation/Tests/CreditEvaluationTests.cs`

**Fix:**
1. Replace `GetConnectionString()` to read from `DatabaseHelper.ConnectionString` (add a public property to `DatabaseHelper` if needed)
2. Replace all `System.Data.SqlClient.SqlConnection` and `System.Data.SqlClient.SqlCommand` with `Microsoft.Data.SqlClient` equivalents

**Pre-flight check:**
```bash
grep -rn "System\.Data\.SqlClient" LoanProcessing.Web/ --include="*.cs"
```

## 5. LoanProcessingTests Missing Interface Declaration

**Symptom:** `/Validation` returns HTTP 500 — `System.InvalidCastException: Unable to cast object of type 'LoanProcessingTests' to type 'IValidationTestCategory'`

**Cause:** `LoanProcessingTests` has all the members of `IValidationTestCategory` (duck typing) but doesn't declare the interface. This works in some .NET Framework reflection scenarios but fails with explicit casts in .NET 10.

**Affected file:** `LoanProcessing.Web/Validation/Tests/LoanProcessingTests.cs`

**Fix:** Add the interface declaration:
```csharp
public class LoanProcessingTests : IValidationTestCategory
```

## 6. Test Packages in Web Project csproj

**Symptom:** Build warnings (NU1510) for unnecessary packages, or test packages inflating the deployment artifact.

**Cause:** AWS Transform migrates `packages.config` to `<PackageReference>` entries but doesn't separate test-only packages from runtime packages. Packages like `Moq`, `Castle.Core`, `MSTest.TestAdapter`, `MSTest.Analyzers`, and `FSharp.Core` end up in the web project.

**Affected file:** `LoanProcessing.Web/LoanProcessing.Web.csproj`

**Fix:** Remove test-infrastructure packages that aren't needed at runtime. Keep `MSTest.TestFramework` and `FsCheck` (used by the embedded PBT tests). Remove `Moq`, `Castle.Core`, `MSTest.TestAdapter`, `MSTest.Analyzers`, `Microsoft.NET.Test.Sdk`, `FSharp.Core`, `System.Runtime.CompilerServices.Unsafe`, `System.Threading.Tasks.Extensions`.

## 7. Vulnerable NuGet Dependencies

**Symptom:** NU1901/NU1902/NU1903 warnings for `Microsoft.Data.SqlClient`, `Azure.Identity`, `jQuery`.

**Fix:**
- Bump `Microsoft.Data.SqlClient` to latest (6.0.1+) to resolve `Azure.Identity` and `Microsoft.Identity.Client` CVEs
- jQuery audit warnings are transitive from `Microsoft.jQuery.Unobtrusive.Validation` (pins jQuery 1.8.0 as a NuGet dep). The actual served jQuery is 3.4.1 via static files. Suppress with `<NoWarn>NU1903;NU1902</NoWarn>` in the csproj.

---

## One-Pass Pre-Flight Check

Run this after every AWS Transform merge to find all remaining `ConfigurationManager` and `System.Data.SqlClient` references before deploying:

```bash
echo "=== ConfigurationManager references ==="
grep -rn "ConfigurationManager\.ConnectionStrings\|ConfigurationManager\.AppSettings" \
  LoanProcessing.Web/ --include="*.cs" \
  | grep -v "Program.cs\|Startup.cs"

echo "=== System.Data.SqlClient references ==="
grep -rn "System\.Data\.SqlClient" LoanProcessing.Web/ --include="*.cs"

echo "=== Parameterless constructors in Controllers ==="
grep -rn "Controller()" LoanProcessing.Web/Controllers/ --include="*.cs"

echo "=== Parameterless constructors in Repositories ==="
grep -rn "Repository()" LoanProcessing.Web/Data/ --include="*.cs"
```

All four checks should return empty after fixes are applied.

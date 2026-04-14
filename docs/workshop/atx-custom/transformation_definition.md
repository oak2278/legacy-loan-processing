# .NET Framework 4.7.2 to .NET 10 Post-Transform Cleanup

## Objective

After AWS Transform for .NET converts a .NET Framework 4.7.2 ASP.NET MVC 5 application to .NET 10 ASP.NET Core, apply the following cleanup steps to ensure the application compiles, runs, and resolves dependencies correctly at runtime.

## Context

AWS Transform handles the bulk conversion (project files, namespaces, startup patterns, EF6→EF Core). However, it preserves legacy parameterless constructors alongside the new DI constructors, and retains `System.Configuration.ConfigurationManager` references that don't work on ASP.NET Core. These cause runtime failures that the build doesn't catch.

## Transformation Rules

### 1. Remove Parameterless Constructors from Controllers

ASP.NET Core's DI container throws `InvalidOperationException: Multiple constructors` when a controller has both a parameterless constructor and a DI constructor.

**Pattern to find:**
```csharp
public class XxxController : Controller
{
    public XxxController()  // ← REMOVE this constructor
    {
        // Manual dependency creation using ConfigurationManager or new
    }

    public XxxController(ISomeService service)  // ← KEEP this constructor
    {
        _service = service;
    }
}
```

**Action:** Remove every parameterless constructor from every controller. Keep only the constructor that accepts injected services.

### 2. Remove Parameterless Constructors from Repositories

Same issue one layer down. Repositories have parameterless constructors that read connection strings via `ConfigurationManager.ConnectionStrings` which returns null on ASP.NET Core.

**Pattern to find:**
```csharp
public class XxxRepository : IXxxRepository
{
    public XxxRepository(string connectionString) { ... }  // ← KEEP

    public XxxRepository()  // ← REMOVE
        : this(ConfigurationManager.ConnectionStrings["..."].ConnectionString)
    { }
}
```

**Action:** Remove the parameterless constructor. Then update `Program.cs` DI registrations from:
```csharp
builder.Services.AddScoped<IXxxRepository, XxxRepository>();
```
To factory lambdas that inject the connection string:
```csharp
var connectionString = builder.Configuration.GetConnectionString("LoanProcessingConnection");
builder.Services.AddScoped<IXxxRepository>(sp => new XxxRepository(connectionString!));
```

### 3. Replace ConfigurationManager References Outside Controllers/Repositories

Any remaining `System.Configuration.ConfigurationManager.ConnectionStrings` or `ConfigurationManager.AppSettings` calls must be replaced with `IConfiguration` injection or `builder.Configuration.GetConnectionString()`.

**Common locations:** Validation controllers, test helpers, service classes that read config directly.

**Action:** Replace with constructor-injected `IConfiguration` and use `configuration.GetConnectionString("name")` or `configuration["key"]`.

### 4. Replace System.Data.SqlClient with Microsoft.Data.SqlClient

AWS Transform updates the main data access layer but may miss references in test files, validation helpers, or utility classes.

**Action:** Replace all `System.Data.SqlClient.SqlConnection`, `System.Data.SqlClient.SqlCommand`, etc. with `Microsoft.Data.SqlClient` equivalents.

### 5. Clean Up csproj Package References

AWS Transform migrates `packages.config` to `<PackageReference>` but may include test packages in the web project.

**Remove from web project if present:** `Moq`, `Castle.Core`, `MSTest.TestAdapter`, `MSTest.Analyzers`, `Microsoft.NET.Test.Sdk`, `FSharp.Core`, `System.Runtime.CompilerServices.Unsafe`, `System.Threading.Tasks.Extensions`

**Keep if embedded tests exist:** `MSTest.TestFramework`, `FsCheck`

**Upgrade:** `Microsoft.Data.SqlClient` to latest (6.0.1+) to resolve known CVEs in transitive dependencies.

### 6. Add Missing Interface Declarations

Classes that implement an interface via duck typing (have all the right members but don't declare `: IInterface`) will fail with `InvalidCastException` at runtime on .NET 10.

**Action:** Search for classes cast to interfaces and verify they declare the interface.

### 7. Add ASPNETCORE_URLS Environment Variable

If the application uses a validation framework or smoke tests that detect the listening port via `Environment.GetEnvironmentVariable("ASPNETCORE_URLS")`, ensure the systemd unit or hosting configuration sets this variable to match the `--urls` argument.

## Build Validation Command

```bash
dotnet build --configuration Release
```

## Runtime Validation

After build succeeds, verify all pages return HTTP 200:
```bash
for page in / /Customer /Loan /Report/Portfolio /InterestRate /Validation; do
  code=$(curl -sf -o /dev/null -w '%{http_code}' http://localhost:5000$page)
  echo "$page: HTTP $code"
done
```

## Pre-Flight Grep Checks

Run after transformation to find remaining issues:
```bash
# Should all return empty after fixes
grep -rn "ConfigurationManager\.ConnectionStrings\|ConfigurationManager\.AppSettings" --include="*.cs" | grep -v "Program.cs\|Startup.cs"
grep -rn "System\.Data\.SqlClient" --include="*.cs"
grep -rn "Controller()" Controllers/ --include="*.cs"
grep -rn "Repository()" Data/ --include="*.cs"
```

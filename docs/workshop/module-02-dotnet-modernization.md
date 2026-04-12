# Module 2: .NET 10 Modernization with AWS Transform

## 1. Overview

### What You Will Accomplish

In this module, you will modernize the LoanProcessing application from .NET Framework 4.7.2 on Windows/IIS to .NET 10 on Amazon Linux/Kestrel. You will use AWS Transform for .NET via the AWS Console to perform the automated code transformation, then use Kiro CLI to apply pre-built CI/CD and infrastructure updates. By the end, the application runs on Linux with Kestrel, traffic is routed through ALB weighted routing, and the Module 1 Windows deployment remains operational alongside the new Linux deployment.

### Why This Matters

- .NET Framework 4.7.2 is Windows-only — modernizing to .NET 10 unlocks cross-platform deployment on Linux
- Kestrel on Linux is lighter, faster, and more cost-effective than IIS on Windows Server
- AWS Transform automates the bulk of the code transformation — you focus on reviewing and validating, not rewriting
- ALB weighted routing gives you a zero-downtime cutover path — verify Linux before switching traffic
- The validation framework proves nothing broke — the same shadow comparison tests that validated Module 1's SP extraction now validate the framework upgrade

### Estimated Time

60–90 minutes

### Tools Used

- **AWS Transform for .NET** (Console web experience) — automated code transformation from .NET Framework to .NET 10
- **Kiro CLI** — apply pre-built stage detector updates and remaining manual fixes
- **Terraform** — provision Linux infrastructure alongside existing Windows resources

---

## 2. Prerequisites

### Expected Starting State

- Module 1 complete — all stored procedure business logic extracted into the C# service layer
- All validation tests passing on the `/validation` dashboard (smoke, data integrity, business logic, shadow comparison, PBT)
- GitHub fork accessible with the Module 1 code on the `main` branch
- EC2 Windows Server instance running IIS with the LoanProcessing .NET Framework 4.7.2 MVC application
- SQL Server (RDS) database operational with all tables and stored procedures
- Application Load Balancer routing traffic to the Windows EC2 instance
- Terraform Module 1 state intact (VPC, subnets, ALB, Windows instances, CI/CD pipeline)

### Verification

Open the application in your browser and navigate to the `/validation` page. Click "Run All Tests" and confirm all tests pass with a green status. The stage label should show **"Post-SP-Extraction (.NET Framework 4.7.2 + SQL Server — SPs Extracted)"** — confirming Module 1 is complete and all business logic lives in the C# service layer.

---

## 3. Architecture

### Before — .NET Framework 4.7.2 on Windows/IIS (Module 1 State)

```
Browser → ALB (port 80) → Windows Server 2022 EC2
                              │
                              ├── IIS Application Pool (.NET 4.7.2)
                              │     └── LoanProcessing.Web
                              │           ├── Global.asax (startup)
                              │           ├── Web.config (connection strings)
                              │           ├── Controllers (System.Web.Mvc.Controller)
                              │           ├── Services (CreditEvaluationCalculator, etc.)
                              │           ├── Data (System.Data.SqlClient + EF6)
                              │           └── Validation (StageDetector, test categories)
                              │
                              └── SQL Server (RDS) — stored procedures + data
```

### After — .NET 10 on Amazon Linux/Kestrel (Module 2 State)

```
                              ┌── tg-windows-80 ──→ Windows Server 2022 EC2 (Module 1 — preserved)
                              │                       └── IIS (.NET 4.7.2, port 80) — still operational
                              │
Browser → ALB ── Listener ────┤   Weighted forward (initially 100% Windows / 0% Linux)
                              │
                              └── tg-linux-5000 ──→ Amazon Linux 2023 EC2 (Module 2 — new)
                                                     └── systemd → Kestrel (.NET 10, port 5000)
                                                           └── LoanProcessing.Web
                                                                 ├── Program.cs (host builder startup)
                                                                 ├── appsettings.json (connection strings)
                                                                 ├── Controllers (Microsoft.AspNetCore.Mvc.Controller)
                                                                 ├── Services (CreditEvaluationCalculator — unchanged)
                                                                 ├── Data (Microsoft.Data.SqlClient + EF Core)
                                                                 └── Validation (StageDetector — updated)

                              SQL Server (RDS) — shared by both deployments
```

After validation, you switch traffic weights to 0% Windows / 100% Linux via `terraform apply`. Both environments remain accessible throughout — you can switch back if needed.

### What Changes vs What Stays

| Component | Before (Module 1) | After (Module 2) |
|---|---|---|
| Runtime | .NET Framework 4.7.2 | .NET 10 |
| Web Framework | ASP.NET MVC 5 | ASP.NET Core MVC |
| ORM | Entity Framework 6.4.4 | Entity Framework Core |
| SQL Client | System.Data.SqlClient | Microsoft.Data.SqlClient |
| Hosting | IIS on Windows Server 2022 | Kestrel on Amazon Linux 2023 |
| Startup | Global.asax / MvcApplication | Program.cs / Host Builder |
| Config | Web.config / ConfigurationManager | appsettings.json / IConfiguration |
| Bundling | BundleConfig / @Scripts.Render | Static file middleware / direct tags |
| DI | Manual `new` in controllers | IServiceCollection constructor injection |
| Build | MSBuild + nuget restore | dotnet CLI (restore, build, publish, test) |
| Deploy Scripts | PowerShell (.ps1) / IIS | Bash (.sh) / systemd/Kestrel |
| Database | SQL Server (RDS) | SQL Server (RDS) — unchanged |
| Business Logic | C# service layer (from Module 1) | C# service layer — unchanged |

### CI/CD Pipeline — Before vs After

```
Before (Module 1):
  GitHub → CodePipeline → CodeBuild (Windows container)
                            ├── nuget restore
                            ├── msbuild /Release
                            ├── xunit.console.exe (PBT)
                            └── xcopy → deployment-package
                          → CodeDeploy (Windows)
                            ├── stop-application.ps1 (IIS stop)
                            ├── before-install.ps1
                            ├── configure-application.ps1 (Web.config)
                            ├── start-application.ps1 (IIS start)
                            └── validate-deployment.ps1

After (Module 2):
  GitHub → CodePipeline → CodeBuild (Linux container)
                            ├── dotnet restore
                            ├── dotnet build
                            ├── dotnet test (PBT)
                            ├── dotnet publish → deployment-package
                          → CodeDeploy (Linux)
                            ├── stop-application.sh (systemd stop)
                            ├── before-install.sh
                            ├── configure-application.sh (appsettings.json via Secrets Manager)
                            ├── start-application.sh (systemd start, verify port 5000)
                            └── validate-deployment.sh
```

---

## 4. Explore the Current Architecture (10–15 min)

Before transforming anything, understand the .NET Framework patterns that will change. This section walks you through the key files and patterns that AWS Transform will convert.

### 4.1 — Examine the Application Startup

Open `LoanProcessing.Web/Global.asax.cs` and notice:

- The `MvcApplication` class inherits from `System.Web.HttpApplication`
- `Application_Start()` configures routes, filters, and bundles — this is the ASP.NET MVC 5 startup pattern
- There is no dependency injection container — controllers create their dependencies manually with `new`

This entire file will be replaced by `Program.cs` using the ASP.NET Core host builder pattern. The host builder provides built-in DI, middleware pipeline configuration, and Kestrel server setup.

### 4.2 — Examine the Configuration Pattern

Open `LoanProcessing.Web/Web.config` and look for the `<connectionStrings>` section:

- Connection strings are stored in XML format under `<configuration><connectionStrings>`
- Code accesses them via `ConfigurationManager.ConnectionStrings["LoanProcessingConnection"]`
- This is the classic .NET Framework configuration pattern

After transformation, connection strings move to `appsettings.json` in JSON format, and code accesses them via `IConfiguration` injection. The `ConfigurationManager` class does not exist in ASP.NET Core.

### 4.3 — Examine the Data Access Pattern

Open any repository file — for example, `LoanProcessing.Web/Data/CustomerRepository.cs` — and notice:

- The `using System.Data.SqlClient` namespace import at the top
- `SqlConnection`, `SqlCommand`, and `SqlParameter` usage for ADO.NET stored procedure calls
- Connection strings retrieved via `ConfigurationManager.ConnectionStrings`

After transformation, `System.Data.SqlClient` becomes `Microsoft.Data.SqlClient`. The ADO.NET patterns (SqlConnection, SqlCommand, SqlParameter, SqlDataReader) remain structurally identical — only the namespace changes. Connection strings are received via constructor injection from DI instead of `ConfigurationManager`.

### 4.4 — Examine the Bundling Pattern

Open `LoanProcessing.Web/App_Start/BundleConfig.cs` and notice:

- CSS and JavaScript files are grouped into bundles (e.g., `~/Content/css`, `~/bundles/jquery`)
- Razor views reference bundles via `@Styles.Render("~/Content/css")` and `@Scripts.Render("~/bundles/jquery")`
- This is the ASP.NET MVC 5 bundling and minification system

After transformation, `BundleConfig` is removed. Razor views reference static files directly with `<link>` and `<script>` tags. ASP.NET Core serves static files via the `UseStaticFiles()` middleware.

### 4.5 — Examine the Controller Base Classes

Open any controller — for example, `LoanProcessing.Web/Controllers/HomeController.cs` — and notice:

- The controller inherits from `System.Web.Mvc.Controller`
- Dependencies are created manually with `new` in the constructor or action methods
- `ActionResult` return types from `System.Web.Mvc`

After transformation, controllers inherit from `Microsoft.AspNetCore.Mvc.Controller`. Dependencies are injected via constructor parameters (registered in `Program.cs`). The `ActionResult` type comes from `Microsoft.AspNetCore.Mvc`.

### 4.6 — Examine the Entity Framework Context

Open `LoanProcessing.Web/Data/LoanProcessingContext.cs` and notice:

- The context inherits from `System.Data.Entity.DbContext` (Entity Framework 6)
- `OnModelCreating` uses `DbModelBuilder` for Fluent API configuration
- Relationship configuration uses `HasRequired(...).WithMany(...).HasForeignKey(...)`
- Identity columns use `HasDatabaseGeneratedOption(DatabaseGeneratedOption.Identity)`

After transformation, the context inherits from `Microsoft.EntityFrameworkCore.DbContext`. The Fluent API changes to EF Core conventions: `ModelBuilder` instead of `DbModelBuilder`, `ValueGeneratedOnAdd()` instead of `HasDatabaseGeneratedOption`, and `HasOne(...).WithMany().HasForeignKey(...).IsRequired()` for relationships.

### 4.7 — Run the Validation Baseline

Navigate to `/validation` in your browser and click "Run All Tests." Confirm:

- **Stage:** "Post-SP-Extraction (.NET Framework 4.7.2 + SQL Server — SPs Extracted)"
- **Smoke tests:** all pages load with HTTP 200
- **Data integrity:** row counts and constraints verified
- **Business logic:** customer CRUD, loan processing, credit evaluation, portfolio reports
- **Shadow comparison:** SP vs Service — all 5 profiles show ✅
- **PBT summary:** FsCheck results from the latest CI build

This is your baseline. After the .NET 10 transformation, every one of these tests must still pass.

---

## 5. Execute the Transformation (30–40 min)

### 5.1 — Use AWS Transform via Console

AWS Transform for .NET automates the bulk of the code transformation. You will use the Console web experience to create a transformation job, review the plan, and execute it.

#### Step 1: Navigate to AWS Transform

1. Open the [AWS Console](https://console.aws.amazon.com/) and search for **"Transform"** in the services search bar
2. Select **AWS Transform for .NET**
3. You will see the AWS Transform dashboard

#### Step 2: Create a Workspace

1. Click **"Create workspace"**
2. Provide a workspace name (e.g., `loan-processing-modernization`)
3. Connect to your GitHub fork:
   - Select **GitHub** as the source provider
   - Authorize AWS Transform to access your GitHub account (if not already connected)
   - Select your forked repository
   - Select the `main` branch
4. Click **"Create"** and wait for the workspace to initialize

> **Note:** AWS Transform needs read/write access to your fork. It will push the transformed code to a new branch for your review.

#### Step 3: Create a Transformation Job

1. In your workspace, click **"Create transformation"**
2. AWS Transform will analyze your repository and detect the .NET Framework solution
3. Select the `LoanProcessing.Web` project (and `LoanProcessing.Tests` if listed separately) as the transformation target
4. Set the target framework to **.NET 10** (`net10.0`)
5. Review the transformation settings and click **"Start transformation"**

#### Step 4: Review the Transformation Plan

AWS Transform will analyze the codebase and present a transformation plan. Review the proposed changes:

- **Project file conversion:** Legacy MSBuild XML → SDK-style format targeting `net10.0`
- **Package migration:** `packages.config` → `<PackageReference>` elements
- **Namespace updates:** `System.Web.Mvc` → `Microsoft.AspNetCore.Mvc`
- **SQL client update:** `System.Data.SqlClient` → `Microsoft.Data.SqlClient`
- **EF migration:** Entity Framework 6 → Entity Framework Core
- **Startup migration:** `Global.asax` → `Program.cs` with host builder
- **Configuration migration:** `Web.config` → `appsettings.json`

Click **"Execute"** to start the transformation.

#### Step 5: Wait for Transformation to Complete

The transformation typically takes 5–15 minutes. AWS Transform will:

1. Convert project files to SDK-style format
2. Update all namespace references
3. Generate `Program.cs` with the host builder pattern
4. Create `appsettings.json` for configuration
5. Update Razor views where needed
6. Push the results to a new branch (e.g., `transform/dotnet10`)

#### Step 6: Review the Transformation Branch

Once complete, AWS Transform shows a summary of changes. Click through to review the transformation branch on GitHub. You will examine the diff in detail in the next step.

### 5.2 — Review and Merge the Transformation Branch

#### Review the Diff

Navigate to your GitHub fork and open the pull request or compare view for the transformation branch (e.g., `transform/dotnet10` → `main`). Review the key changes:

**Project files (`.csproj`):**
- Verify both `LoanProcessing.Web.csproj` and `LoanProcessing.Tests.csproj` target `net10.0`
- Verify `packages.config` references are converted to `<PackageReference>` elements
- Verify SDK-style format (`<Project Sdk="Microsoft.NET.Sdk.Web">`)

**Startup (`Program.cs`):**
- Verify the host builder pattern is present (`WebApplication.CreateBuilder`)
- Verify service registrations for controllers and views (`AddControllersWithViews`)
- Verify static file middleware (`UseStaticFiles`)
- Verify route mapping (`MapControllerRoute`)

**Configuration (`appsettings.json`):**
- Verify connection string section exists under `ConnectionStrings`
- Note: The actual connection string value will be injected at deployment time by the CodeDeploy `configure-application.sh` script

**Controllers:**
- Verify base class changed from `System.Web.Mvc.Controller` to `Microsoft.AspNetCore.Mvc.Controller`
- Verify namespace imports updated

**Repositories:**
- Verify `System.Data.SqlClient` → `Microsoft.Data.SqlClient`
- Verify ADO.NET patterns (SqlConnection, SqlCommand, etc.) are structurally preserved

**Entity Framework:**
- Verify `LoanProcessingContext` inherits from `Microsoft.EntityFrameworkCore.DbContext`
- Verify Fluent API uses EF Core conventions

#### Merge to Main

Once you've reviewed the changes and are satisfied with the transformation:

1. Create a pull request from the transformation branch to `main` (if not already created)
2. Review the diff one more time
3. **Merge the pull request** to `main`

> **Note:** The code may not compile perfectly after merge — AWS Transform handles the bulk of the conversion, but some patterns may need manual fixes. That's what the next step addresses.

### 5.3 — Apply Stage Detector Updates and Manual Fixes with Kiro CLI

After merging the AWS Transform branch, use Kiro CLI to apply the pre-built stage detector updates and fix any remaining issues. These changes are designed to work on the .NET 10 codebase that AWS Transform produced.

#### Pull the Merged Code

```bash
git pull origin main
```

#### Apply Stage Detector Updates

The stage detector needs a new `PostDotNet10` enum value and updated detection logic to recognize .NET 10 + SQL Server + Kestrel as a distinct modernization stage.

Use Kiro to apply the following changes:

1. **New enum value:** `PostDotNet10` added to the `ModernizationStage` enum — represents ".NET 10 + SQL Server + Kestrel"

2. **Updated detection logic:** In the SQL Server branch of `StageDetector.Detect()`, instead of always returning `PreModernization`, the detector now checks `Environment.Version.Major >= 10` and returns `PostDotNet10` if true. A new `IsDotNet10OrLater()` helper method handles the version check with a `RuntimeInformation.FrameworkDescription` fallback.

3. **Display labels:** `ValidationService.GetStageName()` returns `"Post-Module-2 (.NET 10 + SQL Server + Kestrel)"` for the `PostDotNet10` stage.

> **🤖 Kiro Prompt:** "Apply the Module 2 stage detector updates from the spec at `.kiro/specs/dotnet-modernization-module/`. Add the `PostDotNet10` enum value, update `StageDetector.Detect()` with the .NET 10 detection path, and update `ValidationService` display labels."

#### Fix Remaining Manual Issues

AWS Transform handles the bulk of the conversion, but some patterns may need manual intervention. Common fixes include:

- **BundleConfig removal:** If `@Scripts.Render` or `@Styles.Render` references remain in Razor views, replace them with direct `<link>` and `<script>` tags
- **DI registration:** If services or repositories are missing from `Program.cs` DI registration, add them (e.g., `builder.Services.AddScoped<ICustomerRepository, CustomerRepository>()`)
- **EF Core Fluent API:** If `LoanProcessingContext.OnModelCreating` has EF6 patterns that weren't fully converted (e.g., `HasDatabaseGeneratedOption` → `ValueGeneratedOnAdd()`)
- **`_ViewImports.cshtml`:** If missing, create it with `@addTagHelper *, Microsoft.AspNetCore.Mvc.TagHelpers`
- **`HttpContext.Current`:** If any static `HttpContext.Current` references remain, replace with injected `IHttpContextAccessor`
- **`JavaScriptSerializer`:** If `System.Web.Script.Serialization.JavaScriptSerializer` references remain, replace with `System.Text.Json.JsonSerializer`

> **🤖 Kiro Prompt:** "Review the .NET 10 codebase for any remaining compilation errors or ASP.NET MVC 5 patterns that weren't fully converted by AWS Transform. Fix any issues so the project builds cleanly with `dotnet build`."

#### Verify the Build

```bash
dotnet build LoanProcessing.Web/LoanProcessing.Web.csproj --configuration Release
```

If the build succeeds, commit and push your changes:

```bash
git add -A
git commit -m "Apply stage detector updates and manual fixes for .NET 10"
```

> **Note:** Don't push yet — we'll push after provisioning the Linux infrastructure in the next step.

### 5.4 — Provision Module 2 Infrastructure with Terraform

The Module 2 Terraform configuration provisions Linux resources alongside the existing Windows resources. It creates a separate Terraform root module at `aws-deployment/terraform-module2/` with its own state — no existing Module 1 Terraform files are modified.

#### Review the Terraform Configuration

Before applying, review the key resources that will be created:

- **Amazon Linux 2023 EC2 instances** — via a new Auto Scaling Group and launch template
- **Linux target group** (`tg-linux-5000`) — health check on port 5000 for Kestrel
- **ALB weighted listener rule** — routes traffic between the Windows target group (port 80) and Linux target group (port 5000)
- **Linux CI/CD pipeline** — CodeBuild (Linux container), CodeDeploy (Linux), CodePipeline
- **Supporting resources** — S3 artifact bucket, CloudWatch log group, SNS notifications

The existing Module 1 Windows resources (instances, target group, CI/CD pipeline) are untouched.

#### Configure Variables

```bash
cd aws-deployment/terraform-module2
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and populate the variables from your Module 1 outputs:

- `vpc_id` — from Module 1 Terraform output
- `private_subnet_ids` — from Module 1 Terraform output
- `app_security_group_id` — from Module 1 Terraform output
- `alb_listener_arn` — from Module 1 ALB listener
- `windows_target_group_arn` — from Module 1 target group
- `iam_instance_profile_name` — from Module 1 IAM instance profile
- `db_endpoint`, `db_name`, `db_secret_arn` — from Module 1 RDS configuration
- `github_connection_arn`, `github_repository_id` — from Module 1 GitHub connection

#### Initialize and Apply

```bash
terraform init
terraform plan
```

Review the plan output. You should see new resources being created (Linux instances, target group, CI/CD pipeline) and no changes to existing Module 1 resources.

```bash
terraform apply
```

Type `yes` to confirm. The apply typically takes 5–10 minutes.

> **Important:** The initial traffic weights are 100% Windows / 0% Linux. The Linux instances will be provisioned and healthy, but no ALB traffic reaches them yet. You will switch traffic after verifying the Linux deployment.

#### Verify Infrastructure

After `terraform apply` completes:

1. **EC2 Console:** Verify both Windows and Linux instances are running
2. **Target Groups:** Verify `tg-windows-80` (healthy) and `tg-linux-5000` (healthy after deployment)
3. **CodePipeline:** Verify the new Linux pipeline exists (it will trigger on the next push to `main`)

### 5.5 — Push Changes and Trigger the Linux CI/CD Pipeline

Now push your committed changes (stage detector updates + manual fixes) to `main`:

```bash
git push origin main
```

This triggers the new Linux CI/CD pipeline (CodePipeline → CodeBuild → CodeDeploy):

1. **CodeBuild** (Linux container):
   - `dotnet restore` — restores NuGet packages
   - `dotnet build --configuration Release` — compiles the .NET 10 application
   - `dotnet test` — runs FsCheck property-based tests
   - `dotnet publish` — creates the deployment package

2. **CodeDeploy** (Linux instances):
   - `stop-application.sh` — stops the Kestrel systemd service (no-op on first deploy)
   - `before-install.sh` — backs up the current application directory
   - `configure-application.sh` — retrieves the connection string from Secrets Manager and writes `appsettings.json`
   - `start-application.sh` — starts the Kestrel systemd service on port 5000
   - `validate-deployment.sh` — verifies HTTP 200 on `localhost:5000`

> **Note:** The existing Windows CI/CD pipeline also triggers on the push to `main`. This is expected — the Windows pipeline will fail to build the .NET 10 code (since it uses MSBuild/.NET Framework), but this does not affect the Linux pipeline or the existing Windows deployment. The Windows instances continue running the Module 1 code.

#### Monitor the Pipeline

1. Open the **CodePipeline Console** and select the Linux pipeline
2. Watch the **Source** stage pull from GitHub
3. Watch the **Build** stage — verify CodeBuild succeeds (check build logs for `dotnet test` results)
4. Watch the **Deploy** stage — verify CodeDeploy succeeds on the Linux instances

The pipeline typically takes 5–10 minutes to complete.

### 5.6 — Verify the Linux Deployment

Before switching ALB traffic, verify the Linux deployment is working correctly.

#### Option A: Direct Instance Check

1. Find the Linux instance's private IP in the EC2 Console
2. If you have access to the VPC (e.g., via a bastion host or VPN), curl the instance directly:

```bash
curl -f http://<linux-instance-private-ip>:5000/
```

You should get an HTTP 200 response with the LoanProcessing home page.

#### Option B: Target Group Health Check

1. Open the **EC2 Console → Target Groups**
2. Select `tg-linux-5000`
3. Check the **Targets** tab — all registered instances should show **healthy**
4. The health check probes port 5000 on the `/` path

If the health check shows healthy, the Kestrel application is running and responding on port 5000.

### 5.7 — Switch ALB Traffic to Linux

Now that the Linux deployment is verified, switch ALB traffic from Windows to Linux using Terraform:

```bash
cd aws-deployment/terraform-module2
terraform apply -var="windows_traffic_weight=0" -var="linux_traffic_weight=100"
```

Review the plan — it should only change the ALB listener rule weights. Type `yes` to confirm.

```
                                ┌── tg-windows-80 (weight: 0) ──→ Windows EC2 (IIS, port 80)
                                │                                   └── Still operational, no traffic
                                │
Browser → ALB ── Listener ──────┤   Weighted forward action
                                │
                                └── tg-linux-5000 (weight: 100) ──→ Linux EC2 (Kestrel, port 5000)
                                                                     └── All traffic routed here

                                SQL Server (RDS) — shared by both
```

After the apply completes, all ALB traffic routes to the Linux instances. The Windows instances remain running and accessible via their target group — they just don't receive ALB traffic.

> **Rollback:** If anything goes wrong, you can switch back to Windows immediately:
> ```bash
> terraform apply -var="windows_traffic_weight=100" -var="linux_traffic_weight=0"
> ```

---

## 6. Validate (10–15 min)

### 6.1 — Run the Validation Dashboard via ALB

Navigate to the application via the ALB URL (the same URL you've been using throughout the workshop). The ALB now routes to the Linux/Kestrel instances.

Go to `/validation` and click **"Run All Tests."**

#### Verify Stage Detection

The stage label at the top of the results should now show:

> **Stage:** Post-Module-2 (.NET 10 + SQL Server + Kestrel)

This confirms the `StageDetector` correctly identifies the .NET 10 runtime, the SQL Server connection, and the Kestrel hosting environment. If you still see "Post-SP-Extraction" or "Pre-Modernization," the stage detector updates from Step 5.3 may not have been applied correctly.

#### Verify All Test Categories Pass

Review each test category:

- **Smoke Tests:** All application pages (Home, Customer, Loan, Report, InterestRate, Validation) load with HTTP 200. The `ResolveBaseUrl()` method handles Kestrel via the `ASPNETCORE_URLS` environment variable — no changes were needed.

- **Data Integrity:** Row counts, constraints, and sample records match the pre-modernization baseline. The database is unchanged — SQL Server (RDS) is shared by both the Windows and Linux deployments.

- **Business Logic:** Customer CRUD operations, loan processing workflows, and credit evaluation produce identical results. The C# service layer (extracted in Module 1) runs identically on .NET 10.

- **Shadow Comparison:** SP vs Service — all 5 curated loan profiles show ✅. The stored procedures execute via `Microsoft.Data.SqlClient` (instead of `System.Data.SqlClient`), but the behavior is identical. This proves the framework upgrade introduced zero regressions in the business logic.

- **PBT (Property-Based Tests):** The FsCheck results from the latest CI build should show all properties passing. The `CreditEvaluationCalculator` pure math logic runs identically on .NET 10 — the same 100 random inputs per property produce the same results.

All tests should pass with green status. If any test fails, investigate the specific failure before proceeding.

### 6.2 — Cross-Check the Module 1 Windows Instance

The Module 1 Windows deployment should still be operational. Verify this by accessing the Windows instance directly:

#### Option A: Via Windows Target Group

1. Open the **EC2 Console → Target Groups**
2. Select `tg-windows-80`
3. Verify the targets show **healthy** — the Windows instances are still running IIS on port 80

#### Option B: Temporarily Switch Traffic Back

If you want to verify the Windows instance serves the application correctly:

```bash
cd aws-deployment/terraform-module2
terraform apply -var="windows_traffic_weight=100" -var="linux_traffic_weight=0"
```

Navigate to `/validation` via the ALB and run the tests. The stage should show **"Post-SP-Extraction (.NET Framework 4.7.2 + SQL Server — SPs Extracted)"** — confirming the Windows instance is still running the Module 1 code.

Switch traffic back to Linux when done:

```bash
terraform apply -var="windows_traffic_weight=0" -var="linux_traffic_weight=100"
```

### 6.3 — Validation Summary

At this point, you have confirmed:

| Check | Expected Result | Status |
|---|---|---|
| Stage detection | "Post-Module-2 (.NET 10 + SQL Server + Kestrel)" | ✅ |
| Smoke tests | All pages load with HTTP 200 | ✅ |
| Data integrity | Row counts and constraints match baseline | ✅ |
| Business logic | All CRUD and processing tests pass | ✅ |
| Shadow comparison | All 5 profiles match (SP vs Service) | ✅ |
| PBT summary | All FsCheck properties pass on .NET 10 | ✅ |
| Windows instance | Still operational via target group | ✅ |
| Linux instance | Serving traffic via ALB | ✅ |

---

## 7. Key Takeaways

**AWS Transform automates the heavy lifting.** The bulk of the .NET Framework → .NET 10 conversion — project files, namespace changes, startup patterns, configuration migration — is handled automatically. You focus on reviewing the output and fixing edge cases, not rewriting thousands of lines of code.

**Kestrel on Linux is the modern hosting model.** Replacing IIS on Windows Server with Kestrel on Amazon Linux 2023 gives you a lighter, faster, and more cost-effective hosting platform. The systemd service manager provides automatic restarts and clean lifecycle management.

**ALB weighted routing enables zero-downtime cutover.** By running both Windows and Linux deployments simultaneously with weighted target groups, you can verify the new deployment before switching traffic. If anything goes wrong, switching back is a single `terraform apply` command. This is a production-safe migration pattern.

**The validation framework proves continuity.** The same tests that validated Module 1's stored procedure extraction now validate the framework upgrade. Smoke tests, data integrity, business logic, shadow comparison, and property-based tests all pass on .NET 10 — proving the modernization introduced zero functional regressions.

**The Windows environment is preserved.** Module 1's Windows/IIS deployment remains operational throughout Module 2. Both environments share the same SQL Server database. This gives you a reference point for comparison and a rollback path if needed.

**The database is unchanged.** SQL Server (RDS) continues to serve both deployments. Connection strings change format (from `Web.config` XML to `appsettings.json` JSON) and client library (from `System.Data.SqlClient` to `Microsoft.Data.SqlClient`), but the target database, stored procedures, and data are identical.

---

## 8. What's Next

In **Module 3**, you will migrate the database from SQL Server (RDS) to Aurora PostgreSQL using AWS SCT (Schema Conversion Tool) and AWS DMS (Database Migration Service). With the application already running on .NET 10 and all business logic in the C# service layer, the database migration is a pure data operation:

- AWS SCT converts the SQL Server schema (tables, indexes, constraints) to PostgreSQL syntax
- AWS DMS replicates data from SQL Server to Aurora PostgreSQL with minimal downtime
- The application's connection string switches from SQL Server to PostgreSQL
- Entity Framework Core's provider model makes the ORM switch straightforward — `UseSqlServer()` → `UseNpgsql()`
- The stored procedures remain in SQL Server as a reference — they are no longer called by the application (since Module 1)

The validation framework will once again prove nothing broke — the shadow comparison tests, business logic tests, and property-based tests all validate behavioral equivalence after the database migration. The stage detector will advance to `PostModule2` (.NET 10 + Aurora PostgreSQL + Kestrel).

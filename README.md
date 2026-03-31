# Legacy .NET Framework Loan Processing Application

> **⚠️ EDUCATIONAL PROJECT**: This is a demonstration application designed for learning and showcasing legacy .NET Framework patterns. It is **NOT intended for production use**. See [SECURITY.md](SECURITY.md) for important security considerations.

## Overview

This is a legacy .NET Framework 4.7.2 loan processing application that demonstrates typical enterprise patterns from the 2010-2015 era. The application implements significant business logic in MSSQL stored procedures, uses ASP.NET MVC 5 for the presentation layer, and employs a mix of Entity Framework 6.x and ADO.NET for data access.

The application serves as a realistic example for modernization efforts, showcasing:
- Business logic embedded in database stored procedures
- Tight coupling between application and database layers
- Limited testability due to database dependencies
- Manual parameter mapping and result set handling
- Patterns commonly found in legacy financial services applications

## Purpose

This project is intended for:
- **Learning**: Understanding legacy .NET Framework patterns and architecture
- **Training**: Teaching application modernization techniques
- **Reference**: Demonstrating common patterns found in enterprise applications
- **Experimentation**: Testing modernization strategies and tools

**This is NOT production-ready code.** It intentionally includes legacy patterns and practices that should be updated for modern applications.

## Technology Stack

- **Framework**: .NET Framework 4.7.2
- **Web Framework**: ASP.NET MVC 5
- **ORM**: Entity Framework 6.4.4 (for basic CRUD only)
- **Data Access**: ADO.NET (for stored procedure calls)
- **Database**: Microsoft SQL Server 2016+ (or LocalDB for development)
- **UI**: Razor views with Bootstrap 3.4.1
- **JavaScript**: jQuery 3.4.1 for client-side interactions
- **CI/CD**: AWS CodePipeline + CodeBuild + CodeDeploy
- **Infrastructure**: Terraform (VPC, EC2, RDS, ALB)
- **Testing**: FsCheck 2.16.6 (property-based tests), xUnit 2.9.2

## Project Structure

```
LoanProcessing/
├── LoanProcessing.sln                    # Visual Studio solution file
├── buildspec.yml                         # AWS CodeBuild configuration
├── LoanProcessing.Web/                   # ASP.NET MVC 5 web application
│   ├── App_Start/                        # Startup configuration (routing, bundles, filters)
│   ├── Controllers/                      # MVC controllers (Home, Customer, Loan, Report, InterestRate)
│   ├── Models/                           # Domain models (Customer, LoanApplication, LoanDecision, etc.)
│   ├── Data/                             # Repositories (ADO.NET + stored procedure calls)
│   ├── Services/                         # Business logic layer (CustomerService, LoanService, etc.)
│   ├── Views/                            # Razor views
│   │   ├── Shared/_Layout.cshtml         # Master layout
│   │   └── Validation/Index.cshtml       # Validation dashboard (embedded CSS)
│   ├── Validation/                       # Modernization validation framework
│   │   ├── Models/                       # TestResult, ValidationRunResult, ModernizationStage
│   │   ├── Tests/                        # SmokeTests, DataIntegrityTests, Business logic tests
│   │   ├── Helpers/                      # DatabaseHelper, TestDataCleanup, BaselineManager
│   │   ├── StageDetector.cs              # Auto-detects modernization stage
│   │   ├── ValidationService.cs          # Orchestrates test execution
│   │   └── ValidationController.cs       # /Validation route (GET + POST)
│   ├── Web.config                        # Application configuration
│   └── packages.config                   # NuGet package references
├── LoanProcessing.Database/              # SQL Server database project
│   ├── StoredProcedures/                 # Stored procedures
│   └── Scripts/                          # Database setup and migration scripts
├── aws-deployment/                       # AWS CI/CD infrastructure
│   ├── appspec.yml                       # CodeDeploy configuration
│   ├── codedeploy/                       # Deployment lifecycle hooks (PowerShell)
│   └── terraform/                        # Infrastructure as Code (VPC, EC2, RDS, pipeline)
├── database/                             # SQL scripts (schema, stored procs, test scripts)
├── tests/
│   ├── ModernizationTests/               # Property-based tests for validation framework (FsCheck)
│   └── WorkshopGuideTests/               # Workshop guide validation tests
└── docs/                                 # Documentation
```

## Prerequisites

- Visual Studio 2017 or later
- .NET Framework 4.7.2 SDK
- SQL Server 2016+ or SQL Server LocalDB
- IIS Express (included with Visual Studio)

## Getting Started

### 1. Database Setup

The database schema and stored procedures will be created in subsequent tasks. For now, the connection string is configured in `Web.config`:

```xml
<connectionStrings>
  <add name="LoanProcessingConnection" 
       connectionString="Data Source=(localdb)\MSSQLLocalDB;Initial Catalog=LoanProcessing;Integrated Security=True;" 
       providerName="System.Data.SqlClient" />
</connectionStrings>
```

### 2. Build the Solution

1. Open `LoanProcessing.sln` in Visual Studio
2. Restore NuGet packages (right-click solution → Restore NuGet Packages)
3. Build the solution (Ctrl+Shift+B)

### 3. Run the Application

1. Set `LoanProcessing.Web` as the startup project
2. Press F5 to run with debugging or Ctrl+F5 to run without debugging
3. The application will open in your default browser at `http://localhost:51234/`

## Configuration

### Connection Strings

The application uses the following connection string configurations:

- **Development**: LocalDB instance (default)
- **Production**: Update `Web.Release.config` with production connection string

### Application Settings

Key application settings in `Web.config`:
- `ClientValidationEnabled`: Enables client-side validation
- `UnobtrusiveJavaScriptEnabled`: Enables unobtrusive JavaScript validation

## NuGet Packages

The following NuGet packages are included:

### Core Packages
- **EntityFramework** (6.4.4): ORM for basic CRUD operations
- **Microsoft.AspNet.Mvc** (5.2.7): ASP.NET MVC framework
- **Microsoft.AspNet.Razor** (3.2.7): Razor view engine
- **Microsoft.AspNet.WebPages** (3.2.7): Web pages infrastructure

### UI Packages
- **bootstrap** (3.4.1): CSS framework
- **jQuery** (3.4.1): JavaScript library
- **jQuery.Validation** (1.17.0): Client-side validation
- **Microsoft.jQuery.Unobtrusive.Validation** (3.2.11): Unobtrusive validation

### Utility Packages
- **Newtonsoft.Json** (12.0.2): JSON serialization
- **Npgsql** (4.1.13): PostgreSQL data provider (for post-migration validation)
- **Microsoft.AspNet.Web.Optimization** (1.1.3): Bundling and minification


## Deployment

### AWS Deployment (CI/CD Pipeline)

The application deploys to AWS via a fully automated CI/CD pipeline:

- **CodePipeline** triggers on push to `main`
- **CodeBuild** compiles the .NET Framework app and packages artifacts
- **CodeDeploy** deploys to EC2 instances running IIS behind an ALB
- **RDS SQL Server** hosts the database with credentials in Secrets Manager

Infrastructure is managed with Terraform in `aws-deployment/terraform/`.

For full details, see:
- [aws-deployment/README.md](aws-deployment/README.md) — Pipeline architecture and setup
- [aws-deployment/DEPLOYMENT_GUIDE.md](aws-deployment/DEPLOYMENT_GUIDE.md) — Step-by-step deployment instructions

### Local Development

1. **Create Database**:
   ```powershell
   sqlcmd -S "(localdb)\MSSQLLocalDB" -E -i database\CreateDatabase.sql
   sqlcmd -S "(localdb)\MSSQLLocalDB" -E -d LoanProcessing -i database\InitializeSampleData.sql
   ```

2. **Build and Run**:
   - Open `LoanProcessing.sln` in Visual Studio
   - Press F5 to run with IIS Express
   - Navigate to `http://localhost:<port>/`

For more details, see [DEPLOYMENT.md](docs/DEPLOYMENT.md).

## Validation Framework

The application includes a built-in validation framework at the `/Validation` route that verifies functionality across all four modernization stages. Workshop attendees navigate to the page, click "Run All Tests," and see color-coded results inline — no CLI, no separate projects, no configuration.

### What It Tests

- **Smoke Tests** — Verifies all 5 application pages load (Home, Customers, Loans, Reports, Interest Rates)
- **Data Integrity Tests** — Compares row counts, constraints, and sample records against a pre-modernization baseline
- **Business Logic Tests** — Exercises customer CRUD, loan submission, credit evaluation, payment schedules, and portfolio reporting through the service layer

### Stage Detection

The framework automatically detects which modernization stage the app is at by inspecting the connection string, .NET runtime version, and container environment variables:

| Stage | Database | Runtime | Hosting |
|-------|----------|---------|---------|
| Pre-Modernization | SQL Server | .NET Fx 4.7.2 | IIS/EC2 |
| Post-Module-1 | Aurora PostgreSQL | .NET Fx 4.7.2 | IIS/EC2 |
| Post-Module-2 | Aurora PostgreSQL | .NET 8 | Kestrel/EC2 |
| Post-Module-3 | Aurora PostgreSQL | .NET 8 | Container |

### Development-Time Property Tests

A separate `tests/ModernizationTests/` xUnit project validates the framework itself using FsCheck property-based tests (28 tests). Attendees never touch this project.

```powershell
dotnet test tests/ModernizationTests/ModernizationTests.csproj
```

## Modernization Notes

This application intentionally demonstrates legacy patterns that are common modernization targets. It serves as a realistic example for learning and practicing application modernization techniques.

### Legacy Patterns Demonstrated

1. **Database-Centric Logic**: Business rules in stored procedures
   - Credit evaluation logic in `sp_EvaluateCredit`
   - Payment calculation in `sp_CalculatePaymentSchedule`
   - Loan decision processing in `sp_ProcessLoanDecision`
   - Portfolio reporting in `sp_GeneratePortfolioReport`

2. **Tight Coupling**: Direct database dependencies throughout
   - Repositories directly call stored procedures via ADO.NET
   - Services depend on repository implementations
   - Limited abstraction between layers

3. **Manual Mapping**: SqlDataReader to object mapping by hand
   - `MapCustomerFromReader()` in CustomerRepository
   - Manual parameter mapping with `SqlParameter`
   - No automatic object-relational mapping

4. **Limited Dependency Injection**: Minimal DI container usage
   - Manual instantiation of dependencies
   - Tight coupling between controllers and services
   - Hard to test in isolation

5. **Legacy Data Access**: ADO.NET SqlCommand for stored procedures
   - Direct `SqlConnection` and `SqlCommand` usage
   - Manual transaction management
   - No async/await patterns

### Modernization Opportunities

#### Phase 1: Extract Business Logic (Low Risk)
**Goal**: Move business logic from stored procedures to C# while keeping database schema

**Benefits**:
- Improved testability
- Better code organization
- Version control for business logic
- Easier debugging

**Steps**:
1. Create C# classes for business logic (e.g., `CreditEvaluator`, `PaymentCalculator`)
2. Write unit tests for new classes
3. Update repositories to call C# methods instead of stored procedures
4. Keep stored procedures as fallback during transition
5. Remove stored procedures once validated

**Example**:
```csharp
// Before: Stored procedure
EXEC sp_EvaluateCredit @ApplicationId = 1;

// After: C# service
var evaluator = new CreditEvaluator();
var result = evaluator.EvaluateCredit(application, customer);
```

#### Phase 2: Improve Testability (Medium Risk)
**Goal**: Add dependency injection and interfaces for better testing

**Benefits**:
- Unit tests without database
- Mock dependencies easily
- Faster test execution
- Better separation of concerns

**Steps**:
1. Add DI container (e.g., Autofac, Unity)
2. Create interfaces for all services and repositories
3. Register dependencies in DI container
4. Update controllers to use constructor injection
5. Write unit tests with mocked dependencies

#### Phase 3: Upgrade Framework (High Risk)
**Goal**: Migrate from .NET Framework 4.7.2 to .NET 6/8

**Benefits**:
- Cross-platform support (Linux, macOS)
- Better performance
- Modern language features
- Long-term support

**Steps**:
1. Assess compatibility (use .NET Upgrade Assistant)
2. Upgrade to .NET Framework 4.8 first
3. Migrate to .NET 6/8 using upgrade tool
4. Replace ASP.NET MVC 5 with ASP.NET Core MVC
5. Update NuGet packages to .NET Core versions
6. Test thoroughly

#### Phase 4: Modern ORM (Medium Risk)
**Goal**: Replace ADO.NET with Entity Framework Core

**Benefits**:
- LINQ queries instead of SQL
- Automatic change tracking
- Migrations for schema changes
- Better productivity

**Steps**:
1. Install Entity Framework Core
2. Create DbContext with entity configurations
3. Replace repository implementations with EF Core
4. Use LINQ for queries
5. Implement database migrations

#### Phase 5: API-First Architecture (High Risk)
**Goal**: Add RESTful API layer for modern clients

**Benefits**:
- Support mobile apps
- Enable SPA frameworks
- Better scalability
- API versioning

**Steps**:
1. Create ASP.NET Core Web API project
2. Implement RESTful endpoints
3. Add authentication (JWT tokens)
4. Document API with Swagger/OpenAPI
5. Version API endpoints

#### Phase 6: Modern UI (High Risk)
**Goal**: Replace Razor views with modern SPA framework

**Benefits**:
- Better user experience
- Responsive design
- Real-time updates
- Offline capabilities

**Steps**:
1. Choose framework (React, Angular, Vue.js)
2. Create new frontend project
3. Consume API endpoints
4. Implement responsive design
5. Add progressive web app features

### Modernization Best Practices

1. **Incremental Approach**: Modernize in small, testable increments
2. **Strangler Fig Pattern**: Run old and new code side-by-side
3. **Feature Flags**: Control rollout of new features
4. **Comprehensive Testing**: Add tests before refactoring
5. **Monitor Performance**: Track metrics during migration
6. **Document Changes**: Keep modernization log
7. **Team Training**: Ensure team understands new patterns

### Risk Assessment

| Phase | Risk Level | Effort | Business Value |
|-------|-----------|--------|----------------|
| Extract Business Logic | Low | Medium | High |
| Improve Testability | Medium | Medium | High |
| Upgrade Framework | High | High | Medium |
| Modern ORM | Medium | Medium | Medium |
| API-First Architecture | High | High | High |
| Modern UI | High | High | High |

### Success Metrics

- **Code Coverage**: Target 80%+ unit test coverage
- **Performance**: Maintain or improve response times
- **Maintainability**: Reduce cyclomatic complexity
- **Deployment**: Reduce deployment time by 50%
- **Bugs**: Reduce production bugs by 30%

## Documentation

### Getting Started
- **[QUICK_START.md](docs/QUICK_START.md)**: Quick start guide
- **[DATABASE_SETUP.md](docs/DATABASE_SETUP.md)**: Database setup instructions
- **[DATABASE_STATUS.md](docs/DATABASE_STATUS.md)**: Current database status

### Configuration & Deployment
- **[APPLICATION_CONFIGURATION.md](docs/APPLICATION_CONFIGURATION.md)**: Configuration guide
- **[DEPLOYMENT.md](docs/DEPLOYMENT.md)**: Comprehensive deployment guide
- **[aws-deployment/README.md](aws-deployment/README.md)**: AWS CI/CD pipeline architecture
- **[aws-deployment/DEPLOYMENT_GUIDE.md](aws-deployment/DEPLOYMENT_GUIDE.md)**: AWS deployment step-by-step
- **[BUILD_FIXES.md](docs/BUILD_FIXES.md)**: Build issues and fixes
- **[SECURITY_UPDATE.md](docs/SECURITY_UPDATE.md)**: Security updates applied

### Project Information
- **[CHANGELOG.md](docs/CHANGELOG.md)**: Version history
- **[CONTRIBUTING.md](docs/CONTRIBUTING.md)**: Contribution guidelines
- **[DOCUMENTATION_GUIDE.md](docs/DOCUMENTATION_GUIDE.md)**: Documentation standards

### Specifications
- **[Requirements](.kiro/specs/legacy-dotnet-inventory-app/requirements.md)**: Functional requirements
- **[Design](.kiro/specs/legacy-dotnet-inventory-app/design.md)**: Architecture and design
- **[Tasks](.kiro/specs/legacy-dotnet-inventory-app/tasks.md)**: Implementation plan

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Security

Please review [SECURITY.md](SECURITY.md) for important security considerations and responsible disclosure policy.

## Disclaimer

This is a demonstration application for educational purposes only. It is not intended for production use and should not be deployed to handle real financial data or transactions. Always conduct thorough security reviews and testing before deploying any application to production.

## Support

For questions or issues, please refer to the project documentation in `.kiro/specs/legacy-dotnet-inventory-app/` or open an issue on GitHub.

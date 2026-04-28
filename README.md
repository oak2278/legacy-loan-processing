# Legacy .NET Framework Loan Processing Application

> **⚠️ EDUCATIONAL PROJECT**: This is a demonstration application designed for learning and showcasing legacy .NET Framework patterns. It is **NOT intended for production use**. See [SECURITY.md](SECURITY.md) for important security considerations.

## Overview

A legacy .NET Framework 4.7.2 loan processing application that demonstrates typical enterprise patterns from the 2010–2015 era. Business logic lives in MSSQL stored procedures, the presentation layer uses ASP.NET MVC 5, and data access is a mix of Entity Framework 6.x and ADO.NET.

The application serves as a realistic example for modernization efforts — tight coupling between app and database layers, limited testability, manual parameter mapping, and patterns commonly found in legacy financial services applications.

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Framework | .NET Framework 4.7.2 |
| Web | ASP.NET MVC 5.2.7 |
| ORM | Entity Framework 6.4.4 (basic CRUD only) |
| Data Access | ADO.NET (stored procedure calls) |
| Database | SQL Server 2016+ (or LocalDB for development) |
| UI | Razor views, Bootstrap 3.4.1, jQuery 3.7.1 |
| Validation | jQuery.Validation 1.19.5 |
| JSON | Newtonsoft.Json 13.0.3 |
| Testing | MSTest 2.2.10, FsCheck 2.16.6 (property-based tests), Moq 4.18.4 |
| CI/CD | AWS CodePipeline + CodeBuild + CodeDeploy |
| Infrastructure | Terraform (VPC, EC2, RDS, ALB) |

## Project Structure

```
LoanProcessing/
├── LoanProcessing.sln                    # Visual Studio solution
├── buildspec.yml                         # AWS CodeBuild configuration
├── LoanProcessing.Web/                   # ASP.NET MVC 5 web application
│   ├── Controllers/                      # MVC controllers
│   ├── Models/                           # Domain models
│   ├── Data/                             # Repositories (ADO.NET + stored procedures)
│   ├── Services/                         # Business logic layer
│   ├── Views/                            # Razor views
│   ├── Validation/                       # Built-in validation framework
│   ├── Web.config                        # Application configuration
│   └── packages.config                   # NuGet package references
├── LoanProcessing.Database/              # SQL Server database project
│   ├── StoredProcedures/                 # 9 stored procedures
│   └── Scripts/                          # Database setup and migration scripts
├── database/                             # SQL scripts (schema, stored procs, test data)
├── tests/                                # Property-based and workshop tests
├── aws-deployment/                       # AWS CI/CD infrastructure
│   ├── terraform-module1/                # Core infra (VPC, EC2, RDS, ALB)
│   ├── terraform-module2/                # CI/CD pipeline
│   ├── codedeploy/                       # Deployment lifecycle hooks (PowerShell)
│   └── codedeploy-linux/                 # Linux deployment hooks
└── docs/                                 # Documentation
    └── workshop/                         # Workshop module guides
```

## Getting Started

### Prerequisites

- Visual Studio 2017 or later
- .NET Framework 4.7.2 SDK
- SQL Server 2016+ or SQL Server LocalDB

### 1. Database Setup

```powershell
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -i database\CreateDatabase.sql
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -d LoanProcessing -i database\InitializeSampleData.sql
```

### 2. Build and Run

1. Open `LoanProcessing.sln` in Visual Studio
2. Restore NuGet packages (right-click solution → Restore NuGet Packages)
3. Build the solution (Ctrl+Shift+B)
4. Set `LoanProcessing.Web` as the startup project
5. Press F5 — the app opens at `http://localhost:51234/`

### 3. Verify

Navigate through the app: Customers, Loans, Reports, Interest Rates. All pages should load with sample data.

## Validation Framework

The app includes a built-in validation framework at `/Validation` that verifies functionality across modernization stages. Navigate to the page, click "Run All Tests," and see color-coded results — no CLI or separate projects needed.

Tests cover:
- **Smoke tests** — all 5 pages load
- **Data integrity** — row counts, constraints, sample records vs. baseline
- **Business logic** — customer CRUD, loan submission, credit evaluation, payment schedules, portfolio reporting

Stage detection is automatic based on connection string, runtime version, and environment variables.

## AWS Deployment

The application deploys to AWS via a fully automated CI/CD pipeline:

- **CodePipeline** triggers on push to `main`
- **CodeBuild** compiles the .NET Framework app and packages artifacts
- **CodeDeploy** deploys to EC2 instances running IIS behind an ALB
- **RDS SQL Server** hosts the database with credentials in Secrets Manager

Infrastructure is managed with Terraform in `aws-deployment/`.

See:
- [aws-deployment/README.md](aws-deployment/README.md) — Pipeline architecture and setup
- [aws-deployment/DEPLOYMENT_GUIDE.md](aws-deployment/DEPLOYMENT_GUIDE.md) — Step-by-step deployment instructions
- [aws-deployment/ARCHITECTURE.md](aws-deployment/ARCHITECTURE.md) — Infrastructure details

## Legacy Patterns Demonstrated

1. **Database-centric logic** — Business rules in stored procedures (`sp_EvaluateCredit`, `sp_CalculatePaymentSchedule`, `sp_ProcessLoanDecision`, `sp_GeneratePortfolioReport`)
2. **Tight coupling** — Repositories directly call stored procedures via ADO.NET; services depend on concrete implementations
3. **Manual mapping** — `SqlDataReader` to object mapping by hand, manual `SqlParameter` construction
4. **Limited DI** — Manual instantiation of dependencies, hard to test in isolation
5. **Legacy data access** — Direct `SqlConnection`/`SqlCommand` usage, no async/await

## Documentation

| Document | Description |
|----------|-------------|
| [docs/QUICK_START.md](docs/QUICK_START.md) | Quick start guide |
| [docs/DATABASE_SETUP.md](docs/DATABASE_SETUP.md) | Database setup and stored procedure reference |
| [docs/APPLICATION_CONFIGURATION.md](docs/APPLICATION_CONFIGURATION.md) | Web.config and environment configuration |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | Local development and IIS deployment |
| [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) | Contribution guidelines |
| [docs/CHANGELOG.md](docs/CHANGELOG.md) | Version history |
| [SECURITY.md](SECURITY.md) | Security considerations |

## License

MIT — see [LICENSE](LICENSE).

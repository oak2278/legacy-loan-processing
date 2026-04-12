// Program.cs - LoanProcessing.Web (.NET 8.0)
// Replaces the legacy System.Web.HttpApplication / MvcApplication entry-point
// that lived in Global.asax.cs.  The following App_Start classes are fully
// superseded by this file and are retained only as *.bak references:
//
//   App_Start/RouteConfig.cs   -> app.MapControllerRoute() below
//   App_Start/FilterConfig.cs  -> HandleErrorAttribute replaced by
//                                  app.UseExceptionHandler("/Home/Error")
//   App_Start/BundleConfig.cs  -> System.Web.Optimization bundles REMOVED.
//                                  Static assets (jQuery, Bootstrap, modernizr)
//                                  are served directly from wwwroot via
//                                  app.UseStaticFiles(). No bundling/minification
//                                  pipeline is wired in this file.
//
// Web.config settings have been migrated to appsettings.json.

using LoanProcessing.Web;
using LoanProcessing.Web.Data;
using LoanProcessing.Web.Services;

// ---------------------------------------------------------------------------
// 1. Bootstrap the host
// ---------------------------------------------------------------------------
var builder = WebApplication.CreateBuilder(args);

// Expose the IConfiguration instance via the static ConfigurationManager shim
// that legacy repository/service code uses to read connection strings.
// ConfigurationManager is defined in Startup.cs and kept alive here so that
// existing ADO.NET repositories continue to compile without modification.
LoanProcessing.Web.ConfigurationManager.Configuration = builder.Configuration;

// ---------------------------------------------------------------------------
// 2. Service registrations  (replaces Global.asax Application_Start wiring)
// ---------------------------------------------------------------------------

// 2a. MVC + Razor Views
// Replaces AreaRegistration.RegisterAllAreas() and the legacy MVC pipeline.
// HandleErrorAttribute from FilterConfig is replaced by UseExceptionHandler below.
builder.Services.AddControllersWithViews();

// 2b. DbContext
// LoanProcessingContext inherits from System.Data.Entity.DbContext (EF6), not
// Microsoft.EntityFrameworkCore.DbContext, so AddDbContext<> is intentionally
// NOT used here -- that would require an EF Core provider. The EF6 context is
// registered as scoped so DI can resolve it; it self-initialises via its own
// parameterless constructor which reads the named connection string from config.
builder.Services.AddScoped<LoanProcessingContext>();

// 2c. Repository registrations
builder.Services.AddScoped<ICustomerRepository, CustomerRepository>();
builder.Services.AddScoped<ILoanApplicationRepository, LoanApplicationRepository>();
builder.Services.AddScoped<ILoanDecisionRepository, LoanDecisionRepository>();
builder.Services.AddScoped<IPaymentScheduleRepository, PaymentScheduleRepository>();
builder.Services.AddScoped<IReportRepository, ReportRepository>();
builder.Services.AddScoped<IInterestRateRepository, InterestRateRepository>();

// 2d. Service-layer registrations
builder.Services.AddScoped<ICustomerService, CustomerService>();
builder.Services.AddScoped<ILoanService, LoanService>();
builder.Services.AddScoped<IReportService, ReportService>();
builder.Services.AddScoped<IInterestRateService, InterestRateService>();
builder.Services.AddScoped<ICreditEvaluationService, CreditEvaluationService>();

// ---------------------------------------------------------------------------
// 3. Build the application
// ---------------------------------------------------------------------------
var app = builder.Build();

// ---------------------------------------------------------------------------
// 4. Middleware pipeline  (replaces FilterConfig + RouteConfig conventions)
// ---------------------------------------------------------------------------

// 4a. Error handling
// Replaces GlobalFilters.Filters.Add(new HandleErrorAttribute()) from FilterConfig.
if (app.Environment.IsDevelopment())
{
    // Full exception details in development.
    app.UseDeveloperExceptionPage();
}
else
{
    // Render /Home/Error in production -- equivalent to HandleErrorAttribute.
    app.UseExceptionHandler("/Home/Error");
    // Enforce HSTS in non-development environments.
    app.UseHsts();
}

// 4b. HTTPS redirection
app.UseHttpsRedirection();

// 4c. Static files
// Serves content from wwwroot/ (replaces the IIS static-file handler entries
// in system.webServer/handlers and the IgnoreRoute("Content/{*pathInfo}"),
// IgnoreRoute("Scripts/{*pathInfo}"), and IgnoreRoute("fonts/{*pathInfo}")
// calls that were in RouteConfig).
//
// BundleConfig NOTE: System.Web.Optimization bundles for jQuery, Bootstrap,
// and Modernizr have NOT been migrated to this file. Static assets are served
// directly from wwwroot/Scripts and wwwroot/Content via UseStaticFiles().
// Update _Layout.cshtml to reference files directly, for example:
//   <script src="~/Scripts/jquery-3.7.1.min.js"></script>
//   <script src="~/Scripts/bootstrap.min.js"></script>
//   <link  href="~/Content/bootstrap.min.css" rel="stylesheet" />
app.UseStaticFiles();

// 4d. Routing
// RouteConfig.routes.IgnoreRoute("{resource}.axd/{*pathInfo}") is no longer
// required -- .axd handlers do not exist in ASP.NET Core.
app.UseRouting();

// 4e. Authorization
app.UseAuthorization();

// 4f. Controller route mapping
// Mirrors the RouteConfig.RegisterRoutes default route:
//   url:      "{controller}/{action}/{id}"
//   defaults: controller=Home, action=Index, id=UrlParameter.Optional
//   namespaces: LoanProcessing.Web.Controllers, LoanProcessing.Web.Validation
//
// Namespace constraints from RouteConfig are not required in ASP.NET Core MVC.
// Controller discovery is assembly-wide: both LoanProcessing.Web.Controllers
// and LoanProcessing.Web.Validation.ValidationController are automatically
// discoverable because they reside in the same assembly.
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

// ---------------------------------------------------------------------------
// 5. Run
// ---------------------------------------------------------------------------
app.Run();

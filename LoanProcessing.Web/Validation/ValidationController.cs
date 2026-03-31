using System;
using System.Configuration;
using System.Web.Mvc;
using LoanProcessing.Web.Validation.Models;

namespace LoanProcessing.Web.Validation
{
    /// <summary>
    /// MVC controller for the /validation route.
    /// Renders the validation dashboard and triggers test execution.
    /// </summary>
    public class ValidationController : Controller
    {
        private readonly ValidationService _validationService;

        /// <summary>
        /// Initializes a new instance of the ValidationController class.
        /// Reads the connection string from app config and creates the ValidationService.
        /// </summary>
        public ValidationController()
        {
            var connectionString = ConfigurationManager.ConnectionStrings["LoanProcessingConnection"].ConnectionString;
            _validationService = new ValidationService(connectionString);
        }

        /// <summary>
        /// GET /validation — Renders the validation dashboard page with no results yet.
        /// </summary>
        public ActionResult Index()
        {
            return View((ValidationRunResult)null);
        }

        /// <summary>
        /// POST /validation/run — Executes all tests and renders results inline.
        /// </summary>
        [HttpPost]
        public ActionResult Run()
        {
            try
            {
                ValidationRunResult result = _validationService.RunAllTests();
                return View("Index", result);
            }
            catch (Exception ex)
            {
                ViewBag.ErrorMessage = "An error occurred while running validation tests: " + ex.Message;
                return View("Index", (ValidationRunResult)null);
            }
        }
    }
}

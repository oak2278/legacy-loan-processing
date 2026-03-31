using System.Web.Mvc;
using System.Web.Routing;

namespace LoanProcessing.Web
{
    public class RouteConfig
    {
        public static void RegisterRoutes(RouteCollection routes)
        {
            routes.IgnoreRoute("{resource}.axd/{*pathInfo}");

            // Ensure MVC routing takes priority over physical folders (e.g., /Validation)
            routes.RouteExistingFiles = true;

            // Ignore requests for static content folders
            routes.IgnoreRoute("Content/{*pathInfo}");
            routes.IgnoreRoute("Scripts/{*pathInfo}");
            routes.IgnoreRoute("fonts/{*pathInfo}");

            routes.MapRoute(
                name: "Default",
                url: "{controller}/{action}/{id}",
                defaults: new { controller = "Home", action = "Index", id = UrlParameter.Optional },
                namespaces: new[] { "LoanProcessing.Web.Controllers", "LoanProcessing.Web.Validation" }
            );
        }
    }
}

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Net.Http;
using LoanProcessing.Web.Validation.Models;

namespace LoanProcessing.Web.Validation.Tests
{
    /// <summary>
    /// Smoke tests that verify all application pages load correctly
    /// by making HTTP GET requests to each page and checking for
    /// expected status codes and content markers.
    /// </summary>
    public class SmokeTests : IValidationTestCategory
    {
        private readonly string _baseUrl;

        public string CategoryName { get { return "Smoke"; } }

        /// <summary>
        /// Creates a new SmokeTests instance.
        /// </summary>
        /// <param name="baseUrl">
        /// Base URL of the application (e.g., "http://localhost").
        /// If null or empty, attempts to determine from HttpContext.Current,
        /// falling back to "http://localhost".
        /// </param>
        public SmokeTests(string baseUrl = null)
        {
            if (string.IsNullOrWhiteSpace(baseUrl))
            {
                _baseUrl = ResolveBaseUrl();
            }
            else
            {
                _baseUrl = baseUrl.TrimEnd('/');
            }
        }

        public List<TestResult> Run(ModernizationStage stage)
        {
            var results = new List<TestResult>();

            results.Add(TestPage(stage, "/", "Home Page Loads", "Home",
                "Verifies that the Home page loads correctly and the application is serving requests",
                new[] { "Home", "LoanProcessing" }));

            results.Add(TestPage(stage, "/Customer", "Customers Page Loads", "Customers",
                "Verifies that the Customers page loads correctly and displays customer data",
                new[] { "Customers" }));

            results.Add(TestPage(stage, "/Loan", "Loans Page Loads", "Loan",
                "Verifies that the Loans page loads correctly and displays loan application data",
                new[] { "Loan" }));

            results.Add(TestPage(stage, "/Report/Portfolio", "Reports Page Loads", "Report",
                "Verifies that the Reports page loads correctly and displays reporting data",
                new[] { "Report" }));

            results.Add(TestPage(stage, "/InterestRate", "Interest Rates Page Loads", "Interest",
                "Verifies that the Interest Rates page loads correctly and displays rate data",
                new[] { "Interest" }));

            return results;
        }

        private TestResult TestPage(ModernizationStage stage, string path, string testName,
            string contentMarkerLabel, string description, string[] contentMarkers)
        {
            var sw = Stopwatch.StartNew();
            try
            {
                using (var client = new HttpClient())
                {
                    client.Timeout = TimeSpan.FromSeconds(30);
                    var url = _baseUrl + path;
                    var response = client.GetAsync(url).Result;
                    var statusCode = (int)response.StatusCode;
                    var body = response.Content.ReadAsStringAsync().Result;
                    sw.Stop();

                    // Check status code
                    if (statusCode != 200)
                    {
                        return new TestResult
                        {
                            TestName = testName,
                            Category = CategoryName,
                            Description = description,
                            Passed = false,
                            Expected = "HTTP 200 OK",
                            Actual = "HTTP " + statusCode,
                            WhatToCheck = GetSmokeTestHint(stage),
                            Duration = sw.Elapsed
                        };
                    }

                    // Check content markers — at least one must be present
                    bool foundMarker = false;
                    foreach (var marker in contentMarkers)
                    {
                        if (body.IndexOf(marker, StringComparison.OrdinalIgnoreCase) >= 0)
                        {
                            foundMarker = true;
                            break;
                        }
                    }

                    if (!foundMarker)
                    {
                        return new TestResult
                        {
                            TestName = testName,
                            Category = CategoryName,
                            Description = description,
                            Passed = false,
                            Expected = "Page contains '" + contentMarkerLabel + "'",
                            Actual = "Content marker not found in response",
                            WhatToCheck = GetSmokeTestHint(stage),
                            Duration = sw.Elapsed
                        };
                    }

                    return new TestResult
                    {
                        TestName = testName,
                        Category = CategoryName,
                        Description = description,
                        Passed = true,
                        Expected = "HTTP 200 with '" + contentMarkerLabel + "' content",
                        Actual = "HTTP 200 with '" + contentMarkerLabel + "' content",
                        WhatToCheck = string.Empty,
                        Duration = sw.Elapsed
                    };
                }
            }
            catch (Exception ex)
            {
                sw.Stop();
                var innerMessage = ex.InnerException != null ? ex.InnerException.Message : ex.Message;
                return new TestResult
                {
                    TestName = testName,
                    Category = CategoryName,
                    Description = description,
                    Passed = false,
                    Expected = "HTTP 200 OK",
                    Actual = "Connection failed: " + innerMessage,
                    WhatToCheck = GetSmokeTestHint(stage),
                    Duration = sw.Elapsed
                };
            }
        }

        private static string GetSmokeTestHint(ModernizationStage stage)
        {
            switch (stage)
            {
                case ModernizationStage.PreModernization:
                    return "Check that IIS is running and the application pool is started";
                case ModernizationStage.PostModule1:
                    return "Check that the application connection string was updated to Aurora PostgreSQL";
                case ModernizationStage.PostModule2:
                    return "Check that the .NET 8 application builds and runs with dotnet run";
                case ModernizationStage.PostModule3:
                    return "Check that the container is running and port mapping is correct";
                default:
                    return "Check that the application is running and accessible";
            }
        }

        /// <summary>
        /// Attempts to resolve the base URL from HttpContext.Current.
        /// Falls back to "http://localhost" if not available.
        /// </summary>
        private static string ResolveBaseUrl()
        {
            try
            {
                var context = System.Web.HttpContext.Current;
                if (context != null && context.Request != null)
                {
                    var request = context.Request;
                    return request.Url.Scheme + "://" + request.Url.Authority;
                }
            }
            catch
            {
                // HttpContext not available — fall back
            }

            return "http://localhost";
        }
    }
}

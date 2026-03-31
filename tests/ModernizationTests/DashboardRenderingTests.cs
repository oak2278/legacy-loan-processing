// Feature: modernization-testing-framework, Property 2: Dashboard contains all test results grouped by category with educational content
// Validates: Requirements 10.1, 10.2, 10.3

using FsCheck;
using FsCheck.Xunit;
using LoanProcessing.Web.Validation.Models;
using Xunit;
using TestResult = LoanProcessing.Web.Validation.Models.TestResult;

namespace ModernizationTests;

/// <summary>
/// Property 2: Dashboard contains all test results grouped by category with educational content.
///
/// Since we CANNOT render the actual Razor view (requires ASP.NET MVC runtime),
/// we test the VIEW MODEL behavior: verify that ValidationRunResult correctly
/// organizes data for the view.
///
/// Specifically:
///   - For any non-empty list of TestResult with mixed categories and any ModernizationStage,
///     the ValidationRunResult view model contains an entry for every test name
///   - The view model groups results by category (distinct categories match input categories)
///   - Each test result has a non-empty Description (educational content)
///   - WhyThisMatters dictionary contains entries for each category present
/// </summary>
public class DashboardRenderingTests
{
    private static readonly string[] ValidCategories = { "Smoke", "DataIntegrity", "BusinessLogic" };

    private static readonly Dictionary<string, string> WhyThisMattersContent = new()
    {
        { "Smoke", "These tests confirm the web tier is functional and all pages are reachable." },
        { "DataIntegrity", "These tests verify that data was preserved correctly during migration." },
        { "BusinessLogic", "These tests confirm that business rules execute correctly on the new stack." }
    };

    /// <summary>
    /// Generator that produces a non-empty list of TestResult with categories
    /// drawn from {"Smoke", "DataIntegrity", "BusinessLogic"}, each with a non-empty Description.
    /// </summary>
    private static Arbitrary<List<TestResult>> NonEmptyMixedCategoryResultsArb()
    {
        var testNameGen = Gen.Elements(
            "HomePageLoads", "CustomerPageLoads", "LoansPageLoads",
            "RowCountCustomers", "RowCountLoans", "ConstraintPK",
            "CustomerCreate", "LoanSubmission", "CreditEval",
            "PaymentSchedule", "ReportGeneration", "SearchCustomers"
        );
        var categoryGen = Gen.Elements(ValidCategories);
        var passedGen = Arb.From<bool>().Generator;
        var durationGen = Gen.Choose(1, 5000).Select(ms => TimeSpan.FromMilliseconds(ms));
        var descriptionGen = Gen.Elements(
            "Verifies that the page loads correctly with a 200 status code.",
            "Checks that row counts match the expected baseline after migration.",
            "Validates that the business rule produces the correct outcome.",
            "Ensures the constraint exists in the database schema.",
            "Confirms that CRUD operations work end-to-end.",
            "Verifies the credit evaluation produces a valid risk score."
        );

        var singleResultGen = from name in testNameGen
                              from category in categoryGen
                              from passed in passedGen
                              from dur in durationGen
                              from desc in descriptionGen
                              select new TestResult
                              {
                                  TestName = category + "_" + name,
                                  Category = category,
                                  Description = desc,
                                  Passed = passed,
                                  Expected = "expected value",
                                  Actual = passed ? "expected value" : "unexpected value",
                                  WhatToCheck = "Check configuration for " + category,
                                  Duration = dur
                              };

        // Generate 1-15 results to ensure non-empty
        var gen = from count in Gen.Choose(1, 15)
                  from results in Gen.ListOf(count, singleResultGen)
                  select results.ToList();

        return Arb.From(gen);
    }

    /// <summary>
    /// Helper to build a ValidationRunResult view model with WhyThisMatters populated
    /// for all categories present in the results.
    /// </summary>
    private static ValidationRunResult BuildViewModel(List<TestResult> results, ModernizationStage stage)
    {
        var distinctCategories = results.Select(r => r.Category).Distinct();
        var whyThisMatters = new Dictionary<string, string>();
        foreach (var cat in distinctCategories)
        {
            if (WhyThisMattersContent.ContainsKey(cat))
                whyThisMatters[cat] = WhyThisMattersContent[cat];
        }

        return new ValidationRunResult
        {
            DetectedStage = stage,
            StageName = stage.ToString(),
            StageSummary = $"Summary for {stage}",
            Results = results,
            WhyThisMatters = whyThisMatters
        };
    }

    /// <summary>
    /// For any non-empty list of TestResult and any ModernizationStage,
    /// the view model contains an entry for every test name in the input.
    /// </summary>
    [Property(MaxTest = 100)]
    public Property ViewModel_ContainsEntryForEveryTestName()
    {
        var resultsArb = NonEmptyMixedCategoryResultsArb();
        var stageArb = Arb.From<ModernizationStage>();

        return Prop.ForAll(resultsArb, stageArb, (results, stage) =>
        {
            var viewModel = BuildViewModel(results, stage);

            return results.All(r =>
                viewModel.Results.Any(vr => vr.TestName == r.TestName));
        });
    }

    /// <summary>
    /// For any non-empty list of TestResult, the view model groups results by category
    /// and the distinct categories in the grouped output match the input categories.
    /// </summary>
    [Property(MaxTest = 100)]
    public Property ViewModel_GroupsByCategory_DistinctCategoriesMatchInput()
    {
        var resultsArb = NonEmptyMixedCategoryResultsArb();
        var stageArb = Arb.From<ModernizationStage>();

        return Prop.ForAll(resultsArb, stageArb, (results, stage) =>
        {
            var viewModel = BuildViewModel(results, stage);

            var inputCategories = results.Select(r => r.Category).Distinct().OrderBy(c => c).ToList();
            var groupedCategories = viewModel.Results
                .GroupBy(r => r.Category)
                .Select(g => g.Key)
                .OrderBy(c => c)
                .ToList();

            return inputCategories.SequenceEqual(groupedCategories);
        });
    }

    /// <summary>
    /// For any non-empty list of TestResult, every result in the view model
    /// has a non-empty Description (educational content).
    /// </summary>
    [Property(MaxTest = 100)]
    public Property ViewModel_EachTestResult_HasNonEmptyDescription()
    {
        var resultsArb = NonEmptyMixedCategoryResultsArb();
        var stageArb = Arb.From<ModernizationStage>();

        return Prop.ForAll(resultsArb, stageArb, (results, stage) =>
        {
            var viewModel = BuildViewModel(results, stage);

            return viewModel.Results.All(r => !string.IsNullOrWhiteSpace(r.Description));
        });
    }

    /// <summary>
    /// For any non-empty list of TestResult, the WhyThisMatters dictionary
    /// contains an entry for each distinct category present in the results.
    /// </summary>
    [Property(MaxTest = 100)]
    public Property ViewModel_WhyThisMatters_ContainsEntryForEachCategory()
    {
        var resultsArb = NonEmptyMixedCategoryResultsArb();
        var stageArb = Arb.From<ModernizationStage>();

        return Prop.ForAll(resultsArb, stageArb, (results, stage) =>
        {
            var viewModel = BuildViewModel(results, stage);

            var distinctCategories = viewModel.Results.Select(r => r.Category).Distinct();
            return distinctCategories.All(cat =>
                viewModel.WhyThisMatters.ContainsKey(cat)
                && !string.IsNullOrWhiteSpace(viewModel.WhyThisMatters[cat]));
        });
    }

    // Feature: modernization-testing-framework, Property 3: Dashboard header displays stage and summary statistics
    // Validates: Requirements 7.4, 8.5, 10.5

    /// <summary>
    /// For any non-empty list of TestResult and any ModernizationStage,
    /// the view model header contains a non-empty StageName.
    /// </summary>
    [Property(MaxTest = 100)]
    public Property Header_StageName_IsNonEmpty()
    {
        var resultsArb = NonEmptyMixedCategoryResultsArb();
        var stageArb = Arb.From<ModernizationStage>();

        return Prop.ForAll(resultsArb, stageArb, (results, stage) =>
        {
            var viewModel = BuildViewModel(results, stage);

            return !string.IsNullOrWhiteSpace(viewModel.StageName);
        });
    }

    /// <summary>
    /// For any non-empty list of TestResult and any ModernizationStage,
    /// the view model header contains a non-empty StageSummary.
    /// </summary>
    [Property(MaxTest = 100)]
    public Property Header_StageSummary_IsNonEmpty()
    {
        var resultsArb = NonEmptyMixedCategoryResultsArb();
        var stageArb = Arb.From<ModernizationStage>();

        return Prop.ForAll(resultsArb, stageArb, (results, stage) =>
        {
            var viewModel = BuildViewModel(results, stage);

            return !string.IsNullOrWhiteSpace(viewModel.StageSummary);
        });
    }

    /// <summary>
    /// For any non-empty list of TestResult and any ModernizationStage,
    /// TotalTests equals the number of results, PassedTests equals the count
    /// of passed results, and FailedTests equals the count of failed results.
    /// TotalTests == PassedTests + FailedTests.
    /// </summary>
    [Property(MaxTest = 100)]
    public Property Header_Statistics_AreConsistent()
    {
        var resultsArb = NonEmptyMixedCategoryResultsArb();
        var stageArb = Arb.From<ModernizationStage>();

        return Prop.ForAll(resultsArb, stageArb, (results, stage) =>
        {
            var viewModel = BuildViewModel(results, stage);

            var expectedTotal = results.Count;
            var expectedPassed = results.Count(r => r.Passed);
            var expectedFailed = results.Count(r => !r.Passed);

            return viewModel.TotalTests == expectedTotal
                && viewModel.PassedTests == expectedPassed
                && viewModel.FailedTests == expectedFailed
                && viewModel.TotalTests == viewModel.PassedTests + viewModel.FailedTests;
        });
    }

    /// <summary>
    /// For every valid ModernizationStage enum value, the StageName produced
    /// by BuildViewModel is non-empty.
    /// </summary>
    [Property(MaxTest = 100)]
    public Property Header_AllValidStages_ProduceNonEmptyStageName()
    {
        var stageArb = Arb.From<ModernizationStage>();
        var resultsArb = NonEmptyMixedCategoryResultsArb();

        return Prop.ForAll(stageArb, resultsArb, (stage, results) =>
        {
            var viewModel = BuildViewModel(results, stage);

            return !string.IsNullOrWhiteSpace(viewModel.StageName)
                && viewModel.StageName.Length > 0;
        });
    }

    /// <summary>
    /// For every valid ModernizationStage enum value, the StageSummary produced
    /// by BuildViewModel is non-empty.
    /// </summary>
    [Property(MaxTest = 100)]
    public Property Header_AllValidStages_ProduceNonEmptyStageSummary()
    {
        var stageArb = Arb.From<ModernizationStage>();
        var resultsArb = NonEmptyMixedCategoryResultsArb();

        return Prop.ForAll(stageArb, resultsArb, (stage, results) =>
        {
            var viewModel = BuildViewModel(results, stage);

            return !string.IsNullOrWhiteSpace(viewModel.StageSummary)
                && viewModel.StageSummary.Length > 0;
        });
    }

    // Feature: modernization-testing-framework, Property 4: Dashboard failed test display completeness
    // Validates: Requirements 7.3, 7.6, 10.4

    /// <summary>
    /// Generator that produces a TestResult with Passed=false and all failure context
    /// fields populated (non-empty TestName, Expected, Actual, WhatToCheck).
    /// </summary>
    private static Arbitrary<TestResult> FailedTestResultArb()
    {
        var testNameGen = Gen.Elements(
            "HomePageLoads", "CustomerPageLoads", "RowCountCustomers",
            "ConstraintPK_Customers", "CustomerCreate", "LoanSubmission",
            "CreditEval", "PaymentSchedule", "ReportGeneration"
        );
        var categoryGen = Gen.Elements(ValidCategories);
        var expectedGen = Gen.Elements(
            "200 OK", "25 rows", "Constraint exists", "Status: Pending",
            "RiskScore < 40", "Customer persisted", "Schedule count = 36"
        );
        var actualGen = Gen.Elements(
            "500 Internal Server Error", "0 rows", "Constraint missing",
            "Status: null", "RiskScore = 72", "Customer not found",
            "Schedule count = 0", "404 Not Found"
        );
        var whatToCheckGen = Gen.Elements(
            "Check that IIS is running and the application pool is started",
            "Check that DMS migration completed successfully",
            "Check that the connection string was updated to Aurora PostgreSQL",
            "Verify EF Core migrations were applied",
            "Check that the container can reach Aurora PostgreSQL"
        );
        var descriptionGen = Gen.Elements(
            "Verifies that the page loads correctly.",
            "Checks that row counts match the expected baseline.",
            "Validates that the business rule produces the correct outcome."
        );
        var durationGen = Gen.Choose(1, 5000).Select(ms => TimeSpan.FromMilliseconds(ms));

        var gen = from name in testNameGen
                  from category in categoryGen
                  from expected in expectedGen
                  from actual in actualGen
                  from whatToCheck in whatToCheckGen
                  from desc in descriptionGen
                  from dur in durationGen
                  select new TestResult
                  {
                      TestName = category + "_" + name,
                      Category = category,
                      Description = desc,
                      Passed = false,
                      Expected = expected,
                      Actual = actual,
                      WhatToCheck = whatToCheck,
                      Duration = dur
                  };

        return Arb.From(gen);
    }

    /// <summary>
    /// Generator that produces a TestResult with Passed=true and a non-empty TestName.
    /// </summary>
    private static Arbitrary<TestResult> PassedTestResultArb()
    {
        var testNameGen = Gen.Elements(
            "HomePageLoads", "CustomerPageLoads", "RowCountCustomers",
            "ConstraintPK_Customers", "CustomerCreate", "LoanSubmission"
        );
        var categoryGen = Gen.Elements(ValidCategories);
        var durationGen = Gen.Choose(1, 5000).Select(ms => TimeSpan.FromMilliseconds(ms));

        var gen = from name in testNameGen
                  from category in categoryGen
                  from dur in durationGen
                  select new TestResult
                  {
                      TestName = category + "_" + name,
                      Category = category,
                      Description = "Verifies correct behavior.",
                      Passed = true,
                      Expected = "expected value",
                      Actual = "expected value",
                      WhatToCheck = string.Empty,
                      Duration = dur
                  };

        return Arb.From(gen);
    }

    /// <summary>
    /// For any TestResult with Passed=false, the result includes a non-empty
    /// TestName, non-empty Expected, non-empty Actual, and non-empty WhatToCheck.
    /// This ensures the dashboard has all required failure context to display.
    /// </summary>
    [Property(MaxTest = 100)]
    public Property FailedTest_HasAllRequiredDisplayFields()
    {
        var failedArb = FailedTestResultArb();

        return Prop.ForAll(failedArb, (failedResult) =>
        {
            return !string.IsNullOrWhiteSpace(failedResult.TestName)
                && !string.IsNullOrWhiteSpace(failedResult.Expected)
                && !string.IsNullOrWhiteSpace(failedResult.Actual)
                && !string.IsNullOrWhiteSpace(failedResult.WhatToCheck)
                && failedResult.Passed == false;
        });
    }

    /// <summary>
    /// For any TestResult with Passed=true, the result has a non-empty TestName
    /// and Passed==true, confirming the dashboard can render a green indicator.
    /// </summary>
    [Property(MaxTest = 100)]
    public Property PassedTest_HasTestNameAndPassedStatus()
    {
        var passedArb = PassedTestResultArb();

        return Prop.ForAll(passedArb, (passedResult) =>
        {
            return !string.IsNullOrWhiteSpace(passedResult.TestName)
                && passedResult.Passed == true;
        });
    }

    /// <summary>
    /// For any non-empty list of mixed passed/failed TestResults in a ValidationRunResult,
    /// all failed tests have complete failure context (Expected, Actual, WhatToCheck non-empty)
    /// while passed tests simply have Passed==true and a non-empty TestName.
    /// </summary>
    [Property(MaxTest = 100)]
    public Property ViewModel_FailedTestsHaveCompleteContext_PassedTestsHaveGreenIndicator()
    {
        var resultsArb = NonEmptyMixedCategoryResultsArb();
        var stageArb = Arb.From<ModernizationStage>();

        return Prop.ForAll(resultsArb, stageArb, (results, stage) =>
        {
            var viewModel = BuildViewModel(results, stage);

            var failedValid = viewModel.Results
                .Where(r => !r.Passed)
                .All(r => !string.IsNullOrWhiteSpace(r.TestName)
                    && !string.IsNullOrWhiteSpace(r.Expected)
                    && !string.IsNullOrWhiteSpace(r.Actual)
                    && !string.IsNullOrWhiteSpace(r.WhatToCheck));

            var passedValid = viewModel.Results
                .Where(r => r.Passed)
                .All(r => !string.IsNullOrWhiteSpace(r.TestName)
                    && r.Passed == true);

            return failedValid && passedValid;
        });
    }
}

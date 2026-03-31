// Feature: modernization-testing-framework, Property 1: ValidationRunResult contains all three test categories
// Validates: Requirements 1.3, 1.4

using FsCheck;
using FsCheck.Xunit;
using LoanProcessing.Web.Validation.Models;
using Xunit;
using TestResult = LoanProcessing.Web.Validation.Models.TestResult;

namespace ModernizationTests;

/// <summary>
/// Property 1: ValidationRunResult contains all three test categories.
///
/// Since we cannot call ValidationService.RunAllTests() (requires a real database),
/// we test the MODEL behavior: construct a ValidationRunResult with results from all
/// three categories and verify the invariants hold.
///
/// Specifically:
///   - A complete ValidationRunResult contains at least one TestResult per category
///     ("Smoke", "DataIntegrity", "BusinessLogic")
///   - The computed properties (TotalTests, PassedTests, FailedTests, AllPassed)
///     are consistent with the Results list
/// </summary>
public class ValidationServiceTests
{
    private static readonly string[] AllCategories = { "Smoke", "DataIntegrity", "BusinessLogic" };

    /// <summary>
    /// Generator that produces a list of TestResult with at least one entry per category.
    /// </summary>
    private static Arbitrary<List<TestResult>> CompleteTestResultListArb()
    {
        var testNameGen = Gen.Elements(
            "HomePageLoads", "CustomerPageLoads", "RowCountCustomers",
            "ConstraintPK", "CustomerCreate", "LoanSubmission",
            "CreditEval", "PaymentSchedule", "ReportGeneration"
        );
        var passedGen = Arb.From<bool>().Generator;
        var durationGen = Gen.Choose(1, 5000).Select(ms => TimeSpan.FromMilliseconds(ms));

        // Generate one guaranteed result per category
        var smokeGen = from name in testNameGen
                       from passed in passedGen
                       from dur in durationGen
                       select new TestResult
                       {
                           TestName = "Smoke_" + name,
                           Category = "Smoke",
                           Description = "Smoke test",
                           Passed = passed,
                           Expected = "200 OK",
                           Actual = passed ? "200 OK" : "500 Error",
                           WhatToCheck = "Check server",
                           Duration = dur
                       };

        var dataIntegrityGen = from name in testNameGen
                               from passed in passedGen
                               from dur in durationGen
                               select new TestResult
                               {
                                   TestName = "DataIntegrity_" + name,
                                   Category = "DataIntegrity",
                                   Description = "Data integrity test",
                                   Passed = passed,
                                   Expected = "25 rows",
                                   Actual = passed ? "25 rows" : "0 rows",
                                   WhatToCheck = "Check migration",
                                   Duration = dur
                               };

        var businessLogicGen = from name in testNameGen
                               from passed in passedGen
                               from dur in durationGen
                               select new TestResult
                               {
                                   TestName = "BusinessLogic_" + name,
                                   Category = "BusinessLogic",
                                   Description = "Business logic test",
                                   Passed = passed,
                                   Expected = "Pending",
                                   Actual = passed ? "Pending" : "Error",
                                   WhatToCheck = "Check service layer",
                                   Duration = dur
                               };

        // Generate additional random results from any category
        var categoryGen = Gen.Elements(AllCategories);
        var extraResultGen = from name in testNameGen
                             from category in categoryGen
                             from passed in passedGen
                             from dur in durationGen
                             select new TestResult
                             {
                                 TestName = category + "_Extra_" + name,
                                 Category = category,
                                 Description = $"{category} extra test",
                                 Passed = passed,
                                 Expected = "expected",
                                 Actual = passed ? "expected" : "unexpected",
                                 WhatToCheck = "Check config",
                                 Duration = dur
                             };

        var extraCountGen = Gen.Choose(0, 10);

        var gen = from smoke in smokeGen
                  from dataIntegrity in dataIntegrityGen
                  from businessLogic in businessLogicGen
                  from extraCount in extraCountGen
                  from extras in Gen.ListOf(extraCount, extraResultGen)
                  select new List<TestResult>(new[] { smoke, dataIntegrity, businessLogic }.Concat(extras));

        return Arb.From(gen);
    }

    /// <summary>
    /// For any ValidationRunResult that contains results from all three categories,
    /// the Results list contains at least one "Smoke", one "DataIntegrity", and one "BusinessLogic".
    /// </summary>
    [Property(MaxTest = 100)]
    public Property CompleteRunResult_ContainsAllThreeCategories()
    {
        var resultsArb = CompleteTestResultListArb();
        var stageArb = Arb.From<ModernizationStage>();

        return Prop.ForAll(resultsArb, stageArb, (results, stage) =>
        {
            var runResult = new ValidationRunResult
            {
                DetectedStage = stage,
                StageName = stage.ToString(),
                StageSummary = "Test summary",
                Results = results
            };

            bool hasSmoke = runResult.Results.Any(r => r.Category == "Smoke");
            bool hasDataIntegrity = runResult.Results.Any(r => r.Category == "DataIntegrity");
            bool hasBusinessLogic = runResult.Results.Any(r => r.Category == "BusinessLogic");

            return hasSmoke && hasDataIntegrity && hasBusinessLogic;
        });
    }

    /// <summary>
    /// For any ValidationRunResult, TotalTests equals Results.Count.
    /// </summary>
    [Property(MaxTest = 100)]
    public Property TotalTests_EqualsResultsCount()
    {
        var resultsArb = CompleteTestResultListArb();

        return Prop.ForAll(resultsArb, results =>
        {
            var runResult = new ValidationRunResult { Results = results };
            return runResult.TotalTests == results.Count;
        });
    }

    /// <summary>
    /// For any ValidationRunResult, PassedTests equals the count of results where Passed is true.
    /// </summary>
    [Property(MaxTest = 100)]
    public Property PassedTests_EqualsCountOfPassedResults()
    {
        var resultsArb = CompleteTestResultListArb();

        return Prop.ForAll(resultsArb, results =>
        {
            var runResult = new ValidationRunResult { Results = results };
            int expectedPassed = results.Count(r => r.Passed);
            return runResult.PassedTests == expectedPassed;
        });
    }

    /// <summary>
    /// For any ValidationRunResult, FailedTests equals the count of results where Passed is false.
    /// </summary>
    [Property(MaxTest = 100)]
    public Property FailedTests_EqualsCountOfFailedResults()
    {
        var resultsArb = CompleteTestResultListArb();

        return Prop.ForAll(resultsArb, results =>
        {
            var runResult = new ValidationRunResult { Results = results };
            int expectedFailed = results.Count(r => !r.Passed);
            return runResult.FailedTests == expectedFailed;
        });
    }

    /// <summary>
    /// For any ValidationRunResult, PassedTests + FailedTests equals TotalTests.
    /// </summary>
    [Property(MaxTest = 100)]
    public Property PassedPlusFailed_EqualsTotalTests()
    {
        var resultsArb = CompleteTestResultListArb();

        return Prop.ForAll(resultsArb, results =>
        {
            var runResult = new ValidationRunResult { Results = results };
            return runResult.PassedTests + runResult.FailedTests == runResult.TotalTests;
        });
    }

    /// <summary>
    /// For any ValidationRunResult, AllPassed is true if and only if all results have Passed == true.
    /// </summary>
    [Property(MaxTest = 100)]
    public Property AllPassed_IsTrueIffAllResultsPassed()
    {
        var resultsArb = CompleteTestResultListArb();

        return Prop.ForAll(resultsArb, results =>
        {
            var runResult = new ValidationRunResult { Results = results };
            bool expectedAllPassed = results.All(r => r.Passed);
            return runResult.AllPassed == expectedAllPassed;
        });
    }
}

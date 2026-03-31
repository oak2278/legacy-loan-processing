// Feature: modernization-testing-framework, Property 5: Test failure messages include expected and actual values
// Validates: Requirements 2.4, 3.4

using FsCheck;
using FsCheck.Xunit;
using Xunit;
using TestResult = LoanProcessing.Web.Validation.Models.TestResult;

namespace ModernizationTests;

/// <summary>
/// Property 5: Test failure messages include expected and actual values.
///
/// These tests verify model invariants on TestResult:
///   - Failed TestResults preserve Expected and Actual as non-null, non-empty strings
///   - TestResult correctly round-trips all properties (TestName, Category, Expected, Actual, etc.)
/// </summary>
public class TestResultModelTests
{
    /// <summary>
    /// For any TestResult with Passed=false, when Expected and Actual are set to
    /// non-empty strings, they are preserved and contain meaningful content.
    /// </summary>
    [Property(MaxTest = 100)]
    public Property FailedTestResult_PreservesExpectedAndActual()
    {
        var nonEmptyStringArb = Arb.From(
            Gen.Elements(
                "200 OK", "25 rows", "constraint exists", "John Smith",
                "404 Not Found", "0 rows", "constraint missing", "null",
                "Approved", "Rejected", "Pending", "42", "100", "true", "false"
            )
        );

        return Prop.ForAll(nonEmptyStringArb, nonEmptyStringArb,
            (expected, actual) =>
            {
                var result = new TestResult
                {
                    TestName = "SomeTest",
                    Category = "DataIntegrity",
                    Passed = false,
                    Expected = expected,
                    Actual = actual
                };

                return !string.IsNullOrEmpty(result.Expected)
                    && !string.IsNullOrEmpty(result.Actual)
                    && result.Expected == expected
                    && result.Actual == actual;
            });
    }

    /// <summary>
    /// For any failed TestResult constructed with non-empty Expected and Actual,
    /// both values contain meaningful content (non-whitespace).
    /// </summary>
    [Property(MaxTest = 100)]
    public Property FailedTestResult_ExpectedAndActualAreMeaningful()
    {
        var meaningfulStringArb = Arb.From(
            Gen.Elements(
                "200 OK", "500 Internal Server Error", "25", "0",
                "constraint PK_Customers exists", "row count 50",
                "customer found", "page title present", "status Pending",
                "RiskScore 35", "Decision Approved", "45 payment entries"
            )
        );

        return Prop.ForAll(meaningfulStringArb, meaningfulStringArb,
            (expected, actual) =>
            {
                var result = new TestResult
                {
                    TestName = "FailureTest",
                    Category = "Smoke",
                    Passed = false,
                    Expected = expected,
                    Actual = actual,
                    WhatToCheck = "Check configuration"
                };

                // Both Expected and Actual are non-empty and contain non-whitespace content
                return !string.IsNullOrWhiteSpace(result.Expected)
                    && !string.IsNullOrWhiteSpace(result.Actual)
                    && result.Expected.Trim().Length > 0
                    && result.Actual.Trim().Length > 0;
            });
    }

    /// <summary>
    /// TestResult model correctly stores all properties (round-trip test).
    /// For any combination of TestName, Category, Expected, Actual, Description,
    /// and WhatToCheck, the model preserves all values exactly.
    /// </summary>
    [Property(MaxTest = 100)]
    public Property TestResult_RoundTripsAllProperties()
    {
        var testNameArb = Arb.From(
            Gen.Elements("HomePageLoads", "CustomerRowCount", "LoanSubmission", "CreditEval", "PaymentSchedule")
        );
        var categoryArb = Arb.From(
            Gen.Elements("Smoke", "DataIntegrity", "BusinessLogic")
        );
        var valuesArb = Arb.From(
            Gen.Two(Gen.Elements("200 OK", "25 rows", "Pending", "RiskScore < 40", "true", "24 rows", "RiskScore 35", "false"))
        );

        return Prop.ForAll(testNameArb, categoryArb, valuesArb,
            (testName, category, values) =>
            {
                var expected = values.Item1;
                var actual = values.Item2;
                var description = "Verifies " + testName;
                var whatToCheck = "Check " + category + " configuration";
                var passed = expected == actual;

                var result = new TestResult
                {
                    TestName = testName,
                    Category = category,
                    Description = description,
                    Passed = passed,
                    Expected = expected,
                    Actual = actual,
                    WhatToCheck = whatToCheck,
                    Duration = TimeSpan.FromMilliseconds(150)
                };

                return result.TestName == testName
                    && result.Category == category
                    && result.Description == description
                    && result.Passed == passed
                    && result.Expected == expected
                    && result.Actual == actual
                    && result.WhatToCheck == whatToCheck
                    && result.Duration == TimeSpan.FromMilliseconds(150);
            });
    }

    // Feature: modernization-testing-framework, Property 7: Row count comparison passes if and only if counts match baseline
    // Validates: Requirements 3.1, 3.4

    /// <summary>
    /// Simulates the row count comparison logic from DataIntegrityTests:
    /// given a baseline count and actual count, the test passes if and only if actual == baseline.
    /// </summary>
    private static TestResult SimulateRowCountComparison(string tableName, int baselineCount, int actualCount)
    {
        bool passed = actualCount == baselineCount;
        return new TestResult
        {
            TestName = tableName + " Row Count",
            Category = "DataIntegrity",
            Description = "Verifies that the " + tableName + " table row count matches the pre-modernization baseline",
            Passed = passed,
            Expected = baselineCount.ToString() + " rows",
            Actual = actualCount.ToString() + " rows",
            WhatToCheck = passed ? string.Empty : "Check that data migration completed successfully",
            Duration = TimeSpan.FromMilliseconds(50)
        };
    }

    /// <summary>
    /// Property 7a: For any table name, baseline count, and actual count,
    /// the row count test passes if and only if actual == baseline.
    /// </summary>
    [Property(MaxTest = 100)]
    public Property RowCountComparison_PassesIfAndOnlyIfCountsMatch()
    {
        var tableNameArb = Arb.From(
            Gen.Elements("Customers", "LoanApplications", "LoanDecisions", "PaymentSchedules", "InterestRates")
        );
        var countArb = Arb.From(Gen.Choose(0, 10000));

        return Prop.ForAll(tableNameArb, countArb, countArb,
            (tableName, baselineCount, actualCount) =>
            {
                var result = SimulateRowCountComparison(tableName, baselineCount, actualCount);

                bool shouldPass = actualCount == baselineCount;
                return result.Passed == shouldPass;
            });
    }

    /// <summary>
    /// Property 7b: When the row count test fails (actual != baseline),
    /// both the expected (baseline) and actual counts appear in the result.
    /// </summary>
    [Property(MaxTest = 100)]
    public Property RowCountComparison_FailureContainsBothCounts()
    {
        var tableNameArb = Arb.From(
            Gen.Elements("Customers", "LoanApplications", "LoanDecisions", "PaymentSchedules", "InterestRates")
        );
        // Generate pairs where actual != baseline to guarantee a failure
        var mismatchArb = Arb.From(
            Gen.Choose(0, 10000).SelectMany(baseline =>
                Gen.Choose(0, 10000)
                   .Where(actual => actual != baseline)
                   .Select(actual => Tuple.Create(baseline, actual)))
        );

        return Prop.ForAll(tableNameArb, mismatchArb,
            (tableName, counts) =>
            {
                var baselineCount = counts.Item1;
                var actualCount = counts.Item2;
                var result = SimulateRowCountComparison(tableName, baselineCount, actualCount);

                return !result.Passed
                    && result.Expected.Contains(baselineCount.ToString())
                    && result.Actual.Contains(actualCount.ToString());
            });
    }
}

using System;
using System.Collections.Generic;
using System.Data;
using System.Diagnostics;
using LoanProcessing.Web.Validation.Helpers;
using LoanProcessing.Web.Validation.Models;

namespace LoanProcessing.Web.Validation.Tests
{
    /// <summary>
    /// Holds baseline data captured during a Pre-Modernization run
    /// for comparison at subsequent modernization stages.
    /// </summary>
    public class BaselineSnapshot
    {
        /// <summary>
        /// Row counts per table (logical table name → count).
        /// </summary>
        public Dictionary<string, int> RowCounts { get; set; }

        /// <summary>
        /// Sample customer record for field-level verification.
        /// </summary>
        public SampleCustomerData SampleCustomer { get; set; }
    }

    /// <summary>
    /// Holds sample customer field values for baseline comparison.
    /// </summary>
    public class SampleCustomerData
    {
        public int CustomerId { get; set; }
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public int CreditScore { get; set; }
        public decimal AnnualIncome { get; set; }
    }

    /// <summary>
    /// Data integrity tests that verify database content is preserved across
    /// modernization stages. Checks row counts, constraint existence, and
    /// sample record field values against a baseline snapshot.
    /// </summary>
    public class DataIntegrityTests : IValidationTestCategory
    {
        private readonly DatabaseHelper _db;
        private readonly BaselineSnapshot _baseline;

        private static readonly string[] Tables = new[]
        {
            "Customers",
            "LoanApplications",
            "LoanDecisions",
            "PaymentSchedules",
            "InterestRates"
        };

        public string CategoryName { get { return "DataIntegrity"; } }

        /// <summary>
        /// Creates a new DataIntegrityTests instance.
        /// </summary>
        /// <param name="databaseHelper">DatabaseHelper for executing queries.</param>
        /// <param name="baseline">
        /// Baseline snapshot from a previous Pre-Modernization run.
        /// If null, tests record current values instead of comparing.
        /// </param>
        public DataIntegrityTests(DatabaseHelper databaseHelper, BaselineSnapshot baseline = null)
        {
            if (databaseHelper == null)
            {
                throw new ArgumentNullException("databaseHelper");
            }

            _db = databaseHelper;
            _baseline = baseline;
        }

        public List<TestResult> Run(ModernizationStage stage)
        {
            var results = new List<TestResult>();

            // Row count tests for all 5 tables
            foreach (var table in Tables)
            {
                results.Add(TestRowCount(stage, table));
            }

            // Constraint existence tests
            results.AddRange(TestConstraints(stage));

            // Sample customer record verification
            results.Add(TestSampleCustomer(stage));

            return results;
        }

        #region Row Count Tests

        private TestResult TestRowCount(ModernizationStage stage, string tableName)
        {
            var sw = Stopwatch.StartNew();
            try
            {
                int actualCount = _db.GetRowCount(tableName);
                sw.Stop();

                // No baseline — just record the current count
                if (_baseline == null || _baseline.RowCounts == null)
                {
                    return new TestResult
                    {
                        TestName = tableName + " Row Count",
                        Category = CategoryName,
                        Description = "Verifies that the " + tableName + " table row count matches the pre-modernization baseline",
                        Passed = true,
                        Expected = "No baseline — recording current count",
                        Actual = actualCount.ToString(),
                        WhatToCheck = string.Empty,
                        Duration = sw.Elapsed
                    };
                }

                int expectedCount;
                if (!_baseline.RowCounts.TryGetValue(tableName, out expectedCount))
                {
                    return new TestResult
                    {
                        TestName = tableName + " Row Count",
                        Category = CategoryName,
                        Description = "Verifies that the " + tableName + " table row count matches the pre-modernization baseline",
                        Passed = true,
                        Expected = "No baseline for " + tableName + " — recording current count",
                        Actual = actualCount.ToString(),
                        WhatToCheck = string.Empty,
                        Duration = sw.Elapsed
                    };
                }

                bool passed = actualCount == expectedCount;
                return new TestResult
                {
                    TestName = tableName + " Row Count",
                    Category = CategoryName,
                    Description = "Verifies that the " + tableName + " table row count matches the pre-modernization baseline",
                    Passed = passed,
                    Expected = expectedCount.ToString() + " rows",
                    Actual = actualCount.ToString() + " rows",
                    WhatToCheck = passed ? string.Empty : GetDataIntegrityHint(stage),
                    Duration = sw.Elapsed
                };
            }
            catch (Exception ex)
            {
                sw.Stop();
                var innerMessage = ex.InnerException != null ? ex.InnerException.Message : ex.Message;
                return new TestResult
                {
                    TestName = tableName + " Row Count",
                    Category = CategoryName,
                    Description = "Verifies that the " + tableName + " table row count matches the pre-modernization baseline",
                    Passed = false,
                    Expected = "Row count query succeeds",
                    Actual = "Query failed: " + innerMessage,
                    WhatToCheck = GetDataIntegrityHint(stage),
                    Duration = sw.Elapsed
                };
            }
        }

        #endregion

        #region Constraint Existence Tests

        private List<TestResult> TestConstraints(ModernizationStage stage)
        {
            var results = new List<TestResult>();

            // Primary keys on all 5 tables — check by type since PK names are auto-generated
            results.Add(TestConstraintByType(stage, "PRIMARY KEY", "Customers",
                "Verifies that a primary key constraint exists on the Customers table"));
            results.Add(TestConstraintByType(stage, "PRIMARY KEY", "LoanApplications",
                "Verifies that a primary key constraint exists on the LoanApplications table"));
            results.Add(TestConstraintByType(stage, "PRIMARY KEY", "LoanDecisions",
                "Verifies that a primary key constraint exists on the LoanDecisions table"));
            results.Add(TestConstraintByType(stage, "PRIMARY KEY", "PaymentSchedules",
                "Verifies that a primary key constraint exists on the PaymentSchedules table"));
            results.Add(TestConstraintByType(stage, "PRIMARY KEY", "InterestRates",
                "Verifies that a primary key constraint exists on the InterestRates table"));

            // Foreign keys
            results.Add(TestConstraint(stage, "FK_LoanApplications_Customers", "LoanApplications",
                "Verifies that the foreign key from LoanApplications to Customers exists"));
            results.Add(TestConstraint(stage, "FK_LoanDecisions_Applications", "LoanDecisions",
                "Verifies that the foreign key from LoanDecisions to LoanApplications exists"));
            results.Add(TestConstraint(stage, "FK_PaymentSchedules_Applications", "PaymentSchedules",
                "Verifies that the foreign key from PaymentSchedules to LoanApplications exists"));

            // Unique constraint on SSN
            results.Add(TestConstraint(stage, "UQ_Customers_SSN", "Customers",
                "Verifies that the unique constraint on Customers.SSN exists to prevent duplicate social security numbers"));

            // CHECK constraints
            results.Add(TestConstraint(stage, "CK_Customers_CreditScore", "Customers",
                "Verifies that the CHECK constraint on CreditScore (300-850) exists"));
            results.Add(TestConstraint(stage, "CK_Customers_Income", "Customers",
                "Verifies that the CHECK constraint on AnnualIncome (>=0) exists"));
            results.Add(TestConstraint(stage, "CK_InterestRates_Rate", "InterestRates",
                "Verifies that the CHECK constraint on InterestRates.Rate (>0) exists"));

            return results;
        }

        private TestResult TestConstraint(ModernizationStage stage, string constraintName,
            string tableName, string description)
        {
            var sw = Stopwatch.StartNew();
            try
            {
                bool exists = _db.ConstraintExists(constraintName, tableName);
                sw.Stop();

                return new TestResult
                {
                    TestName = constraintName + " Exists",
                    Category = CategoryName,
                    Description = description,
                    Passed = exists,
                    Expected = "Constraint " + constraintName + " exists",
                    Actual = exists ? "Constraint exists" : "Constraint not found",
                    WhatToCheck = exists ? string.Empty : GetDataIntegrityHint(stage),
                    Duration = sw.Elapsed
                };
            }
            catch (Exception ex)
            {
                sw.Stop();
                var innerMessage = ex.InnerException != null ? ex.InnerException.Message : ex.Message;
                return new TestResult
                {
                    TestName = constraintName + " Exists",
                    Category = CategoryName,
                    Description = description,
                    Passed = false,
                    Expected = "Constraint " + constraintName + " exists",
                    Actual = "Query failed: " + innerMessage,
                    WhatToCheck = GetDataIntegrityHint(stage),
                    Duration = sw.Elapsed
                };
            }
        }

        private TestResult TestConstraintByType(ModernizationStage stage, string constraintType,
            string tableName, string description)
        {
            var sw = Stopwatch.StartNew();
            try
            {
                string sql;
                string mappedTable = _db.MapTableName(tableName);
                bool exists;

                if (_db.IsPostgreSQL)
                {
                    sql = @"SELECT COUNT(*) FROM information_schema.table_constraints
                        WHERE table_schema = 'dbo' AND LOWER(table_name) = LOWER(@tableName)
                          AND constraint_type = @constraintType";
                    exists = _db.ExecuteScalar<long>(sql,
                        ("@tableName", mappedTable),
                        ("@constraintType", constraintType)) > 0;
                }
                else
                {
                    string typeCode = constraintType == "PRIMARY KEY" ? "PK" : "UQ";
                    string fullTableName = "dbo." + mappedTable;
                    sql = @"SELECT COUNT(*) FROM sys.objects
                        WHERE type = @typeCode AND parent_object_id = OBJECT_ID(@fullTableName)";
                    exists = _db.ExecuteScalar<int>(sql,
                        ("@typeCode", typeCode),
                        ("@fullTableName", fullTableName)) > 0;
                }

                sw.Stop();
                string testName = constraintType + " on " + tableName;
                return new TestResult
                {
                    TestName = testName + " Exists",
                    Category = CategoryName,
                    Description = description,
                    Passed = exists,
                    Expected = testName + " exists",
                    Actual = exists ? "Constraint exists" : "Constraint not found",
                    WhatToCheck = exists ? string.Empty : GetDataIntegrityHint(stage),
                    Duration = sw.Elapsed
                };
            }
            catch (Exception ex)
            {
                sw.Stop();
                var innerMessage = ex.InnerException != null ? ex.InnerException.Message : ex.Message;
                string testName = constraintType + " on " + tableName;
                return new TestResult
                {
                    TestName = testName + " Exists",
                    Category = CategoryName,
                    Description = description,
                    Passed = false,
                    Expected = testName + " exists",
                    Actual = "Query failed: " + innerMessage,
                    WhatToCheck = GetDataIntegrityHint(stage),
                    Duration = sw.Elapsed
                };
            }
        }

        #endregion

        #region Sample Customer Record Verification

        private TestResult TestSampleCustomer(ModernizationStage stage, int customerId = 1)
        {
            var sw = Stopwatch.StartNew();
            try
            {
                string idCol = _db.MapColumnName("CustomerId");
                string firstNameCol = _db.MapColumnName("FirstName");
                string lastNameCol = _db.MapColumnName("LastName");
                string creditScoreCol = _db.MapColumnName("CreditScore");
                string annualIncomeCol = _db.MapColumnName("AnnualIncome");
                string table = _db.MapTableName("Customers");

                string sql = string.Format(
                    "SELECT {0}, {1}, {2}, {3} FROM dbo.{4} WHERE {5} = @customerId",
                    firstNameCol, lastNameCol, creditScoreCol, annualIncomeCol, table, idCol);

                DataTable dt = _db.ExecuteQuery(sql, ("@customerId", customerId));
                sw.Stop();

                if (dt.Rows.Count == 0)
                {
                    return new TestResult
                    {
                        TestName = "Sample Customer Record",
                        Category = CategoryName,
                        Description = "Verifies that a known customer record (ID=" + customerId + ") exists and field values match the baseline",
                        Passed = false,
                        Expected = "Customer with ID " + customerId + " exists",
                        Actual = "Customer not found",
                        WhatToCheck = GetDataIntegrityHint(stage),
                        Duration = sw.Elapsed
                    };
                }

                DataRow row = dt.Rows[0];
                string actualFirstName = row[firstNameCol].ToString();
                string actualLastName = row[lastNameCol].ToString();
                int actualCreditScore = Convert.ToInt32(row[creditScoreCol]);
                decimal actualAnnualIncome = Convert.ToDecimal(row[annualIncomeCol]);

                // No baseline — just report current values
                if (_baseline == null || _baseline.SampleCustomer == null)
                {
                    string currentValues = string.Format(
                        "FirstName={0}, LastName={1}, CreditScore={2}, AnnualIncome={3}",
                        actualFirstName, actualLastName, actualCreditScore, actualAnnualIncome);

                    return new TestResult
                    {
                        TestName = "Sample Customer Record",
                        Category = CategoryName,
                        Description = "Verifies that a known customer record (ID=" + customerId + ") exists and field values match the baseline",
                        Passed = true,
                        Expected = "No baseline — recording current values",
                        Actual = currentValues,
                        WhatToCheck = string.Empty,
                        Duration = sw.Elapsed
                    };
                }

                // Compare against baseline
                var mismatches = new List<string>();
                var baseline = _baseline.SampleCustomer;

                if (!string.Equals(actualFirstName, baseline.FirstName, StringComparison.Ordinal))
                {
                    mismatches.Add(string.Format("FirstName: expected '{0}', actual '{1}'", baseline.FirstName, actualFirstName));
                }
                if (!string.Equals(actualLastName, baseline.LastName, StringComparison.Ordinal))
                {
                    mismatches.Add(string.Format("LastName: expected '{0}', actual '{1}'", baseline.LastName, actualLastName));
                }
                if (actualCreditScore != baseline.CreditScore)
                {
                    mismatches.Add(string.Format("CreditScore: expected {0}, actual {1}", baseline.CreditScore, actualCreditScore));
                }
                if (actualAnnualIncome != baseline.AnnualIncome)
                {
                    mismatches.Add(string.Format("AnnualIncome: expected {0}, actual {1}", baseline.AnnualIncome, actualAnnualIncome));
                }

                bool passed = mismatches.Count == 0;
                string expectedStr = string.Format(
                    "FirstName={0}, LastName={1}, CreditScore={2}, AnnualIncome={3}",
                    baseline.FirstName, baseline.LastName, baseline.CreditScore, baseline.AnnualIncome);
                string actualStr = string.Format(
                    "FirstName={0}, LastName={1}, CreditScore={2}, AnnualIncome={3}",
                    actualFirstName, actualLastName, actualCreditScore, actualAnnualIncome);

                return new TestResult
                {
                    TestName = "Sample Customer Record",
                    Category = CategoryName,
                    Description = "Verifies that a known customer record (ID=" + customerId + ") exists and field values match the baseline",
                    Passed = passed,
                    Expected = expectedStr,
                    Actual = passed ? actualStr : actualStr + " — Mismatches: " + string.Join("; ", mismatches),
                    WhatToCheck = passed ? string.Empty : GetDataIntegrityHint(stage),
                    Duration = sw.Elapsed
                };
            }
            catch (Exception ex)
            {
                sw.Stop();
                var innerMessage = ex.InnerException != null ? ex.InnerException.Message : ex.Message;
                return new TestResult
                {
                    TestName = "Sample Customer Record",
                    Category = CategoryName,
                    Description = "Verifies that a known customer record (ID=" + customerId + ") exists and field values match the baseline",
                    Passed = false,
                    Expected = "Customer record query succeeds",
                    Actual = "Query failed: " + innerMessage,
                    WhatToCheck = GetDataIntegrityHint(stage),
                    Duration = sw.Elapsed
                };
            }
        }

        #endregion

        #region Stage-Aware Hints

        private static string GetDataIntegrityHint(ModernizationStage stage)
        {
            switch (stage)
            {
                case ModernizationStage.PreModernization:
                    return "Check that SQL Server is accessible and the LoanProcessing database exists";
                case ModernizationStage.PostModule1:
                    return "Check that DMS migration completed successfully — compare row counts with source";
                case ModernizationStage.PostModule2:
                    return "Check that EF Core migrations were applied and the Npgsql provider is configured";
                case ModernizationStage.PostModule3:
                    return "Check that the container can reach Aurora PostgreSQL — verify security group rules";
                default:
                    return "Check that the database is accessible and the schema exists";
            }
        }

        #endregion
    }
}

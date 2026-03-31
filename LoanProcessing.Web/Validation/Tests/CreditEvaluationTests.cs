using System;
using System.Collections.Generic;
using System.Diagnostics;
using LoanProcessing.Web.Models;
using LoanProcessing.Web.Services;
using LoanProcessing.Web.Validation.Helpers;
using LoanProcessing.Web.Validation.Models;

namespace LoanProcessing.Web.Validation.Tests
{
    public class CreditEvaluationTests : IValidationTestCategory
    {
        private readonly ILoanService _loanService;
        private readonly ICustomerService _customerService;
        private readonly TestDataCleanup _cleanup;
        private readonly CustomerBusinessTests _customerTests;

        public string CategoryName { get { return "BusinessLogic"; } }

        public CreditEvaluationTests(ILoanService loanService, ICustomerService customerService, TestDataCleanup cleanup, CustomerBusinessTests customerTests)
        {
            _loanService = loanService;
            _customerService = customerService;
            _cleanup = cleanup;
            _customerTests = customerTests;
        }

        public List<TestResult> Run(ModernizationStage stage)
        {
            var results = new List<TestResult>();
            results.Add(TestHighCreditScore(stage));
            results.Add(TestLowCreditScore(stage));
            results.Add(TestDebtToIncomeRatio(stage));

            // Final cleanup of all test data
            _cleanup.CleanupBySSNPrefix("999-");
            return results;
        }

        private void UpdateCustomerScore(int customerId, int creditScore, decimal annualIncome)
        {
            var customer = _customerService.GetById(customerId);
            customer.CreditScore = creditScore;
            customer.AnnualIncome = annualIncome;
            _customerService.UpdateCustomer(customer);
        }

        private TestResult TestHighCreditScore(ModernizationStage stage)
        {
            var sw = Stopwatch.StartNew();
            try
            {
                int customerId = _customerTests.LastCreatedCustomerId;
                if (customerId <= 0) return Fail(sw, "High Credit Score Risk Assessment", "Evaluates credit for a high credit score customer", "RiskScore < 40", "Create Customer test must pass first", stage);

                // Customer already has CreditScore=780 from the Update test
                var app = new LoanApplication { CustomerId = customerId, LoanType = "Personal", RequestedAmount = 30000m, TermMonths = 36, Purpose = "Validation - high credit score" };
                int appId = _loanService.SubmitLoanApplication(app);
                LoanDecision decision = _loanService.EvaluateCredit(appId);
                sw.Stop();

                if (decision == null || !decision.RiskScore.HasValue)
                    return Fail(sw, "High Credit Score Risk Assessment", "Evaluates credit for a high credit score customer", "RiskScore <= 40", "RiskScore is null", stage);

                bool passed = decision.RiskScore.Value <= 40;
                return new TestResult { TestName = "High Credit Score Risk Assessment", Category = CategoryName, Description = "Evaluates credit for a customer with a high credit score (780) and verifies the risk score is at or below 40, confirming low-risk classification", Passed = passed, Expected = "RiskScore <= 40", Actual = "RiskScore = " + decision.RiskScore.Value, WhatToCheck = passed ? string.Empty : GetHint(stage), Duration = sw.Elapsed };
            }
            catch (Exception ex) { sw.Stop(); return Fail(sw, "High Credit Score Risk Assessment", "Evaluates credit for a high credit score customer", "RiskScore < 40", "Exception: " + ex.Message, stage); }
        }

        private TestResult TestLowCreditScore(ModernizationStage stage)
        {
            var sw = Stopwatch.StartNew();
            try
            {
                int customerId = _customerTests.LastCreatedCustomerId;
                if (customerId <= 0) return Fail(sw, "Low Credit Score Risk Assessment", "Evaluates credit for a low credit score customer", "RiskScore > 60", "Create Customer test must pass first", stage);

                // Update to low credit score
                UpdateCustomerScore(customerId, 550, 35000m);

                var app = new LoanApplication { CustomerId = customerId, LoanType = "Personal", RequestedAmount = 15000m, TermMonths = 24, Purpose = "Validation - low credit score" };
                int appId = _loanService.SubmitLoanApplication(app);
                LoanDecision decision = _loanService.EvaluateCredit(appId);
                sw.Stop();

                if (decision == null || !decision.RiskScore.HasValue)
                    return Fail(sw, "Low Credit Score Risk Assessment", "Evaluates credit for a low credit score customer", "RiskScore > 60", "RiskScore is null", stage);

                bool passed = decision.RiskScore.Value > 60;
                return new TestResult { TestName = "Low Credit Score Risk Assessment", Category = CategoryName, Description = "Evaluates credit for a customer with a low credit score (550) and verifies the risk score is above 60, confirming high-risk classification", Passed = passed, Expected = "RiskScore > 60", Actual = "RiskScore = " + decision.RiskScore.Value, WhatToCheck = passed ? string.Empty : GetHint(stage), Duration = sw.Elapsed };
            }
            catch (Exception ex) { sw.Stop(); return Fail(sw, "Low Credit Score Risk Assessment", "Evaluates credit for a low credit score customer", "RiskScore > 60", "Exception: " + ex.Message, stage); }
        }

        private TestResult TestDebtToIncomeRatio(ModernizationStage stage)
        {
            var sw = Stopwatch.StartNew();
            try
            {
                int customerId = _customerTests.LastCreatedCustomerId;
                if (customerId <= 0) return Fail(sw, "Debt-to-Income Ratio Calculation", "Evaluates credit with existing loans", "DebtToIncomeRatio > 0", "Create Customer test must pass first", stage);

                // Update to moderate credit score for DTI test
                UpdateCustomerScore(customerId, 700, 80000m);

                // Customer already has approved loans from earlier tests — DTI should be calculated
                var loan = new LoanApplication { CustomerId = customerId, LoanType = "Personal", RequestedAmount = 15000m, TermMonths = 24, Purpose = "Validation - DTI evaluation" };
                int loanId = _loanService.SubmitLoanApplication(loan);
                LoanDecision decision = _loanService.EvaluateCredit(loanId);
                sw.Stop();

                if (decision == null)
                    return Fail(sw, "Debt-to-Income Ratio Calculation", "Evaluates credit with existing approved loans and verifies DTI is calculated", "DebtToIncomeRatio > 0", "LoanDecision is null", stage);

                if (!decision.DebtToIncomeRatio.HasValue)
                    return Fail(sw, "Debt-to-Income Ratio Calculation", "Evaluates credit with existing approved loans and verifies DTI is calculated", "DebtToIncomeRatio > 0", "DebtToIncomeRatio is null", stage);

                bool passed = decision.DebtToIncomeRatio.Value > 0;
                return new TestResult { TestName = "Debt-to-Income Ratio Calculation", Category = CategoryName, Description = "Evaluates credit for a customer with an existing approved loan and verifies the debt-to-income ratio is calculated and included in the decision", Passed = passed, Expected = "DebtToIncomeRatio > 0", Actual = "DebtToIncomeRatio = " + decision.DebtToIncomeRatio.Value, WhatToCheck = passed ? string.Empty : GetHint(stage), Duration = sw.Elapsed };
            }
            catch (Exception ex) { sw.Stop(); return Fail(sw, "Debt-to-Income Ratio Calculation", "Evaluates credit with existing loans", "DebtToIncomeRatio > 0", "Exception: " + ex.Message, stage); }
        }

        private TestResult Fail(Stopwatch sw, string name, string desc, string expected, string actual, ModernizationStage stage)
        {
            return new TestResult { TestName = name, Category = CategoryName, Description = desc, Passed = false, Expected = expected, Actual = actual, WhatToCheck = GetHint(stage), Duration = sw.Elapsed };
        }

        private static string GetHint(ModernizationStage stage)
        {
            switch (stage)
            {
                case ModernizationStage.PreModernization: return "Check that SQL Server stored procedures for credit evaluation are accessible and return correct risk scores";
                case ModernizationStage.PostModule1: return "Check that credit evaluation logic works with Aurora PostgreSQL";
                case ModernizationStage.PostModule2: return "Check that credit evaluation business rules were correctly ported to the .NET 8 service layer";
                case ModernizationStage.PostModule3: return "Check that the container can reach Aurora PostgreSQL and credit evaluation services are functioning";
                default: return "Check that the credit evaluation service and database connection are configured correctly";
            }
        }
    }
}

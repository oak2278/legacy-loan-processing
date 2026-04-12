using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using LoanProcessing.Web.Models;
using LoanProcessing.Web.Services;
using LoanProcessing.Web.Validation.Helpers;
using LoanProcessingModernizationStage = LoanProcessing.Web.Validation.Models.ModernizationStage;

using LoanProcessingTestResult = LoanProcessing.Web.Validation.Models.TestResult;

namespace LoanProcessing.Web.Validation.Tests
{
    public class LoanProcessingTests
    {
        private readonly ILoanService _loanService;
        private readonly IReportService _reportService;
        private readonly CustomerBusinessTests _customerTests;

        public string CategoryName { get { return "BusinessLogic"; } }

        public LoanProcessingTests(ILoanService loanService, IReportService reportService, CustomerBusinessTests customerTests)
        {
            _loanService = loanService;
            _reportService = reportService;
            _customerTests = customerTests;
        }

        public List<LoanProcessingTestResult> Run(LoanProcessingModernizationStage stage)
        {
            var results = new List<LoanProcessingTestResult>();
            // Reuse the customer created by CustomerBusinessTests
            int customerId = _customerTests.LastCreatedCustomerId;

            results.Add(TestSubmitLoanApplication(stage, customerId));
            results.Add(TestCreditEvaluation(stage, customerId));
            results.Add(TestProcessLoanDecision(stage, customerId));
            results.Add(TestPaymentSchedule(stage, customerId));
            results.Add(TestPortfolioReport(stage));
            return results;
        }

        private LoanProcessingTestResult TestSubmitLoanApplication(LoanProcessingModernizationStage stage, int customerId)
        {
            var sw = Stopwatch.StartNew();
            try
            {
                if (customerId <= 0) return Fail(sw, "Submit Loan Application", "Submits a loan application and verifies Pending status", "Test customer exists", "Create Customer test must pass first", stage);

                var app = new LoanApplication { CustomerId = customerId, LoanType = "Personal", RequestedAmount = 25000m, TermMonths = 36, Purpose = "Validation test loan" };
                int appId = _loanService.SubmitLoanApplication(app);
                var retrieved = _loanService.GetApplicationById(appId);
                sw.Stop();

                if (retrieved == null) return Fail(sw, "Submit Loan Application", "Submits a loan application and verifies Pending status", "Application retrievable", "Not found after submission", stage);
                if (retrieved.Status != "Pending") return Fail(sw, "Submit Loan Application", "Submits a loan application and verifies Pending status", "Status = 'Pending'", "Status = '" + retrieved.Status + "'", stage);

                return Pass(sw, "Submit Loan Application", "Submits a loan application for a test customer and verifies it is created with Pending status", "Application ID=" + appId + ", Status=Pending");
            }
            catch (Exception ex) { sw.Stop(); return Fail(sw, "Submit Loan Application", "Submits a loan application and verifies Pending status", "Loan submitted", "Exception: " + ex.Message, stage); }
        }

        private LoanProcessingTestResult TestCreditEvaluation(LoanProcessingModernizationStage stage, int customerId)
        {
            var sw = Stopwatch.StartNew();
            try
            {
                if (customerId <= 0) return Fail(sw, "Credit Evaluation", "Evaluates credit and verifies risk score and recommendation", "Test customer exists", "Create Customer test must pass first", stage);

                var app = new LoanApplication { CustomerId = customerId, LoanType = "Personal", RequestedAmount = 25000m, TermMonths = 36, Purpose = "Validation test - credit eval" };
                int appId = _loanService.SubmitLoanApplication(app);
                LoanDecision decision = _loanService.EvaluateCredit(appId);
                sw.Stop();

                if (decision == null) return Fail(sw, "Credit Evaluation", "Evaluates credit and verifies risk score and recommendation", "LoanDecision returned", "LoanDecision is null", stage);

                var issues = new List<string>();
                if (!decision.RiskScore.HasValue) issues.Add("RiskScore is null");
                else if (decision.RiskScore.Value < 0 || decision.RiskScore.Value > 100) issues.Add("RiskScore out of range: " + decision.RiskScore.Value);

                string recommendation = decision.Comments;
                if (string.IsNullOrEmpty(recommendation)) issues.Add("Recommendation is empty");

                if (issues.Count > 0) return Fail(sw, "Credit Evaluation", "Submits a loan and triggers credit evaluation, verifying the decision includes a valid risk score and a recommendation", "RiskScore 0-100 with recommendation", string.Join("; ", issues), stage);

                return Pass(sw, "Credit Evaluation", "Submits a loan and triggers credit evaluation, verifying the decision includes a valid risk score and a recommendation", "RiskScore=" + decision.RiskScore.Value + ", Recommendation=" + recommendation);
            }
            catch (Exception ex) { sw.Stop(); return Fail(sw, "Credit Evaluation", "Evaluates credit and verifies risk score and recommendation", "Credit evaluation completed", "Exception: " + ex.Message, stage); }
        }

        private LoanProcessingTestResult TestProcessLoanDecision(LoanProcessingModernizationStage stage, int customerId)
        {
            var sw = Stopwatch.StartNew();
            try
            {
                if (customerId <= 0) return Fail(sw, "Process Loan Decision", "Processes a loan decision and verifies status update", "Test customer exists", "Create Customer test must pass first", stage);

                var app = new LoanApplication { CustomerId = customerId, LoanType = "Personal", RequestedAmount = 25000m, TermMonths = 36, Purpose = "Validation test - process decision" };
                int appId = _loanService.SubmitLoanApplication(app);
                _loanService.EvaluateCredit(appId);
                _loanService.ProcessLoanDecision(appId, "Approved", "Validation test approval", "ValidationFramework");

                var updated = _loanService.GetApplicationById(appId);
                sw.Stop();

                if (updated == null) return Fail(sw, "Process Loan Decision", "Processes a loan decision (approve) and verifies the application status is updated", "Application retrievable", "Not found after decision", stage);
                if (updated.Status != "Approved") return Fail(sw, "Process Loan Decision", "Processes a loan decision (approve) and verifies the application status is updated", "Status = 'Approved'", "Status = '" + updated.Status + "'", stage);

                return Pass(sw, "Process Loan Decision", "Processes a loan decision (approve) and verifies the application status is updated", "Application ID=" + appId + ", Status=Approved");
            }
            catch (Exception ex) { sw.Stop(); return Fail(sw, "Process Loan Decision", "Processes a loan decision and verifies status update", "Decision processed", "Exception: " + ex.Message, stage); }
        }

        private LoanProcessingTestResult TestPaymentSchedule(LoanProcessingModernizationStage stage, int customerId)
        {
            var sw = Stopwatch.StartNew();
            try
            {
                if (customerId <= 0) return Fail(sw, "Payment Schedule", "Verifies payment schedule for approved loan", "Test customer exists", "Create Customer test must pass first", stage);

                var app = new LoanApplication { CustomerId = customerId, LoanType = "Personal", RequestedAmount = 25000m, TermMonths = 36, Purpose = "Validation test - payment schedule" };
                int appId = _loanService.SubmitLoanApplication(app);
                LoanDecision decision = _loanService.EvaluateCredit(appId);

                if (decision == null || string.IsNullOrEmpty(decision.Comments) || decision.Comments == "Rejected")
                {
                    sw.Stop();
                    return Pass(sw, "Payment Schedule", "For an approved loan, retrieves the payment schedule and verifies the number of entries matches the loan term", "Loan not approved - skipping payment schedule verification");
                }

                _loanService.ProcessLoanDecision(appId, "Approved", "Validation test approval", "ValidationFramework");
                var schedule = _loanService.GetPaymentSchedule(appId);
                sw.Stop();
                var scheduleList = schedule != null ? schedule.ToList() : new List<PaymentSchedule>();

                if (scheduleList.Count != 36) return Fail(sw, "Payment Schedule", "For an approved loan, retrieves the payment schedule and verifies the number of entries matches the loan term", "36 entries", scheduleList.Count + " entries", stage);

                return Pass(sw, "Payment Schedule", "For an approved loan, retrieves the payment schedule and verifies the number of entries matches the loan term", "36 payment entries");
            }
            catch (Exception ex) { sw.Stop(); return Fail(sw, "Payment Schedule", "Verifies payment schedule for approved loan", "Payment schedule retrieved", "Exception: " + ex.Message, stage); }
        }

        private LoanProcessingTestResult TestPortfolioReport(LoanProcessingModernizationStage stage)
        {
            var sw = Stopwatch.StartNew();
            try
            {
                var report = _reportService.GeneratePortfolioReport(null, null, null);
                sw.Stop();

                if (report == null || report.Summary == null) return Fail(sw, "Portfolio Report", "Generates a portfolio report and verifies aggregated data", "Report with Summary", "Report or Summary is null", stage);
                if (report.Summary.TotalLoans <= 0) return Fail(sw, "Portfolio Report", "Generates a portfolio report and verifies aggregated data", "TotalLoans > 0", "TotalLoans = " + report.Summary.TotalLoans, stage);

                return Pass(sw, "Portfolio Report", "Generates a portfolio report with no filters and verifies it returns aggregated data including total loan count and approved amount", "TotalLoans=" + report.Summary.TotalLoans + ", TotalApprovedAmount=" + report.Summary.TotalApprovedAmount);
            }
            catch (Exception ex) { sw.Stop(); return Fail(sw, "Portfolio Report", "Generates a portfolio report and verifies aggregated data", "Report generated", "Exception: " + ex.Message, stage); }
        }

        private LoanProcessingTestResult Pass(Stopwatch sw, string name, string desc, string actual)
        {
            return new LoanProcessingTestResult { TestName = name, Category = CategoryName, Description = desc, Passed = true, Expected = actual, Actual = actual, WhatToCheck = string.Empty, Duration = sw.Elapsed };
        }

        private LoanProcessingTestResult Fail(Stopwatch sw, string name, string desc, string expected, string actual, LoanProcessingModernizationStage stage)
        {
            return new LoanProcessingTestResult { TestName = name, Category = CategoryName, Description = desc, Passed = false, Expected = expected, Actual = actual, WhatToCheck = GetHint(stage), Duration = sw.Elapsed };
        }

        private static string GetHint(LoanProcessingModernizationStage stage)
        {
            switch (stage)
            {
                case LoanProcessingModernizationStage.PreModernization: return "Check that SQL Server stored procedures for loan processing are accessible and the service layer is configured correctly";
                case LoanProcessingModernizationStage.PostModule1: return "Check that loan processing logic works with Aurora PostgreSQL";
                case LoanProcessingModernizationStage.PostModule2: return "Check that EF Core migrations include loan tables and the Npgsql provider is configured";
                case LoanProcessingModernizationStage.PostModule3: return "Check that the container can reach Aurora PostgreSQL and loan processing services are functioning";
                default: return "Check that the loan service layer and database connection are configured correctly";
            }
        }
    }
}
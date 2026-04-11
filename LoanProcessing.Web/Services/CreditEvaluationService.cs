using System;
using LoanProcessing.Web.Data;
using LoanProcessing.Web.Models;

namespace LoanProcessing.Web.Services
{
    public class CreditEvaluationService : ICreditEvaluationService
    {
        private readonly ILoanApplicationRepository _loanAppRepo;
        private readonly ICustomerRepository _customerRepo;
        private readonly IInterestRateRepository _rateRepo;

        public CreditEvaluationService(
            ILoanApplicationRepository loanAppRepo,
            ICustomerRepository customerRepo,
            IInterestRateRepository rateRepo)
        {
            _loanAppRepo = loanAppRepo;
            _customerRepo = customerRepo;
            _rateRepo = rateRepo;
        }

        public LoanDecision Evaluate(int applicationId)
        {
            if (applicationId <= 0)
                throw new ArgumentException("Application ID must be greater than zero.", "applicationId");

            var application = _loanAppRepo.GetById(applicationId);
            if (application == null)
                throw new InvalidOperationException(
                    string.Format("Loan application with ID {0} was not found.", applicationId));

            var customer = _customerRepo.GetById(application.CustomerId);
            if (customer == null)
                throw new InvalidOperationException(
                    string.Format("Customer for application {0} was not found.", applicationId));

            if (customer.AnnualIncome <= 0)
                throw new InvalidOperationException("Customer annual income must be greater than zero for credit evaluation.");

            var existingDebt = _loanAppRepo.GetApprovedAmountsByCustomer(application.CustomerId, applicationId);
            var dtiRatio = CreditEvaluationCalculator.CalculateDtiRatio(existingDebt, application.RequestedAmount, customer.AnnualIncome);
            var riskScore = CreditEvaluationCalculator.CalculateRiskScore(customer.CreditScore, dtiRatio);
            var recommendation = CreditEvaluationCalculator.DetermineRecommendation(riskScore, dtiRatio);

            var rateResult = _rateRepo.GetRateByCriteria(application.LoanType, customer.CreditScore, application.TermMonths, DateTime.Now);
            var interestRate = rateResult != null ? rateResult.Rate : CreditEvaluationCalculator.DefaultInterestRate;

            _loanAppRepo.UpdateStatusAndRate(applicationId, "UnderReview", interestRate);

            return new LoanDecision
            {
                ApplicationId = applicationId,
                RiskScore = riskScore,
                DebtToIncomeRatio = dtiRatio,
                InterestRate = interestRate,
                Comments = recommendation
            };
        }
    }
}

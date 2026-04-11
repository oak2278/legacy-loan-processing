using System;

namespace LoanProcessing.Web.Services
{
    public static class CreditEvaluationCalculator
    {
        public const decimal DefaultInterestRate = 12.99m;

        public static decimal CalculateDtiRatio(decimal existingDebt, decimal requestedAmount, decimal annualIncome)
        {
            if (annualIncome <= 0)
                throw new InvalidOperationException("Customer annual income must be greater than zero for credit evaluation.");
            return Math.Round(((existingDebt + requestedAmount) / annualIncome) * 100, 4);
        }

        public static int CalculateCreditScoreComponent(int creditScore)
        {
            if (creditScore >= 750) return 10;
            if (creditScore >= 700) return 20;
            if (creditScore >= 650) return 35;
            if (creditScore >= 600) return 50;
            return 75;
        }

        public static int CalculateDtiComponent(decimal dtiRatio)
        {
            if (dtiRatio <= 20) return 0;
            if (dtiRatio <= 35) return 10;
            if (dtiRatio <= 43) return 20;
            return 30;
        }

        public static int CalculateRiskScore(int creditScore, decimal dtiRatio)
        {
            int raw = CalculateCreditScoreComponent(creditScore) + CalculateDtiComponent(dtiRatio);
            return Math.Min(100, Math.Max(0, raw));
        }

        public static string DetermineRecommendation(int riskScore, decimal dtiRatio)
        {
            if (riskScore <= 30 && dtiRatio <= 35)
                return "Recommended for Approval";
            if (riskScore <= 50 && dtiRatio <= 43)
                return "Manual Review Required";
            return "High Risk - Recommend Rejection";
        }
    }
}

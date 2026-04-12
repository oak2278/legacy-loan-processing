using System;
using FsCheck;
using FsCheck.Fluent;
using FsCheck.Xunit;
using LoanProcessing.Web.Services;

namespace LoanProcessing.Tests
{
    public class CreditEvaluationCalculatorProperties
    {
        [Property(MaxTest = 100)]
        public Property DtiRatio_MatchesFormula()
        {
            var arb = ArbMap.Default.ArbFor<int>().Filter(x => x >= 0 && x <= 500000)
                .Convert(x => (decimal)x, x => (int)x);
            var arb2 = ArbMap.Default.ArbFor<int>().Filter(x => x >= 1 && x <= 500000)
                .Convert(x => (decimal)x, x => (int)x);
            var combined = Arb.From(
                arb.Generator.SelectMany(existingDebt =>
                    arb.Generator.SelectMany(requestedAmount =>
                        arb2.Generator.Select(annualIncome =>
                            (existingDebt, requestedAmount, annualIncome)))));
            return Prop.ForAll(combined, tuple =>
            {
                var (existingDebt, requestedAmount, annualIncome) = tuple;
                decimal expected = Math.Round(((existingDebt + requestedAmount) / annualIncome) * 100, 4);
                decimal actual = CreditEvaluationCalculator.CalculateDtiRatio(existingDebt, requestedAmount, annualIncome);
                return actual == expected;
            });
        }

        [Property(MaxTest = 100)]
        public Property CreditScoreComponent_ReturnsValidBracket()
        {
            var arb = ArbMap.Default.ArbFor<int>().Filter(x => x >= 300 && x <= 850);
            return Prop.ForAll(arb, creditScore =>
            {
                int result = CreditEvaluationCalculator.CalculateCreditScoreComponent(creditScore);
                return result == 10 || result == 20 || result == 35 || result == 50 || result == 75;
            });
        }

        [Property(MaxTest = 100)]
        public Property DtiComponent_ReturnsValidBracket()
        {
            var arb = ArbMap.Default.ArbFor<int>().Filter(x => x >= 0 && x <= 20000)
                .Convert(x => (decimal)x / 100m, x => (int)(x * 100m));
            return Prop.ForAll(arb, dtiRatio =>
            {
                int result = CreditEvaluationCalculator.CalculateDtiComponent(dtiRatio);
                return result == 0 || result == 10 || result == 20 || result == 30;
            });
        }

        [Property(MaxTest = 100)]
        public Property RiskScore_InRangeAndEqualsComponentSum()
        {
            var arbScore = ArbMap.Default.ArbFor<int>().Filter(x => x >= 300 && x <= 850);
            var arbDti = ArbMap.Default.ArbFor<int>().Filter(x => x >= 0 && x <= 20000)
                .Convert(x => (decimal)x / 100m, x => (int)(x * 100m));
            var combined = Arb.From(
                arbScore.Generator.SelectMany(creditScore =>
                    arbDti.Generator.Select(dtiRatio => (creditScore, dtiRatio))));
            return Prop.ForAll(combined, tuple =>
            {
                var (creditScore, dtiRatio) = tuple;
                int result = CreditEvaluationCalculator.CalculateRiskScore(creditScore, dtiRatio);
                int expectedRaw = Math.Min(100, Math.Max(0,
                    CreditEvaluationCalculator.CalculateCreditScoreComponent(creditScore) +
                    CreditEvaluationCalculator.CalculateDtiComponent(dtiRatio)));
                return result >= 0 && result <= 100 && result == expectedRaw;
            });
        }

        [Property(MaxTest = 100)]
        public Property Recommendation_ReturnsValidCategory()
        {
            var arbScore = ArbMap.Default.ArbFor<int>().Filter(x => x >= 0 && x <= 100);
            var arbDti = ArbMap.Default.ArbFor<int>().Filter(x => x >= 0 && x <= 20000)
                .Convert(x => (decimal)x / 100m, x => (int)(x * 100m));
            var combined = Arb.From(
                arbScore.Generator.SelectMany(riskScore =>
                    arbDti.Generator.Select(dtiRatio => (riskScore, dtiRatio))));
            return Prop.ForAll(combined, tuple =>
            {
                var (riskScore, dtiRatio) = tuple;
                string result = CreditEvaluationCalculator.DetermineRecommendation(riskScore, dtiRatio);
                return result == "Recommended for Approval"
                    || result == "Manual Review Required"
                    || result == "High Risk - Recommend Rejection";
            });
        }
    }
}

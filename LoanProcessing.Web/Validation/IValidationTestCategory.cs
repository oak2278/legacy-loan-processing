using System.Collections.Generic;
using LoanProcessing.Web.Validation.Models;

namespace LoanProcessing.Web.Validation
{
    public interface IValidationTestCategory
    {
        string CategoryName { get; }
        List<LoanProcessing.Web.Validation.Models.TestResult> Run(ModernizationStage stage);
    }
}
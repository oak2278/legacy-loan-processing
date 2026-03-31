using System.Collections.Generic;
using LoanProcessing.Web.Validation.Models;

namespace LoanProcessing.Web.Validation
{
    public interface IValidationTestCategory
    {
        string CategoryName { get; }
        List<TestResult> Run(ModernizationStage stage);
    }
}

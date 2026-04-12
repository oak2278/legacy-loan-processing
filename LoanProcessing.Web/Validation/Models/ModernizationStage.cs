namespace LoanProcessing.Web.Validation.Models
{
    public enum ModernizationStage
    {
        PreModernization,    // .NET Fx 4.7.2 + SQL Server + IIS
        PostModule1,         // .NET Fx 4.7.2 + Aurora PostgreSQL + IIS
        PostModule2,         // .NET 8 + Aurora PostgreSQL + Kestrel
        PostDotNet10,        // .NET 10 + SQL Server + Kestrel
        PostModule3          // .NET 8 + Aurora PostgreSQL + Container
    }
}

using System;

namespace LoanProcessing.Web.Validation.Models
{
    public class TestResult
    {
        public string TestName { get; set; }
        public string Category { get; set; }
        public string Description { get; set; }
        public bool Passed { get; set; }
        public string Expected { get; set; }
        public string Actual { get; set; }
        public string WhatToCheck { get; set; }
        public TimeSpan Duration { get; set; }
    }
}

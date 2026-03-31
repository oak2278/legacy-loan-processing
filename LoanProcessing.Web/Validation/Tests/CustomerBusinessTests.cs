using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using LoanProcessing.Web.Models;
using LoanProcessing.Web.Services;
using LoanProcessing.Web.Validation.Helpers;
using LoanProcessing.Web.Validation.Models;

namespace LoanProcessing.Web.Validation.Tests
{
    public class CustomerBusinessTests : IValidationTestCategory
    {
        private readonly ICustomerService _customerService;
        private readonly TestDataCleanup _cleanup;
        private const string TestSSN = "999-99-9999";

        public string CategoryName { get { return "BusinessLogic"; } }

        // Expose the created customer ID so LoanProcessingTests can reuse it
        public int LastCreatedCustomerId { get; private set; }

        public CustomerBusinessTests(ICustomerService customerService, TestDataCleanup cleanup)
        {
            _customerService = customerService;
            _cleanup = cleanup;
        }

        public List<TestResult> Run(ModernizationStage stage)
        {
            var results = new List<TestResult>();

            // Clean slate
            _cleanup.CleanupBySSNPrefix("999-");

            // Tests flow as a pipeline: create → retrieve → update → search
            results.Add(TestCreateCustomer(stage));
            results.Add(TestRetrieveCustomer(stage));
            results.Add(TestUpdateCustomer(stage));
            results.Add(TestSearchCustomer(stage));

            // Don't clean up here — LoanProcessingTests will reuse this customer
            return results;
        }

        private TestResult TestCreateCustomer(ModernizationStage stage)
        {
            var sw = Stopwatch.StartNew();
            try
            {
                var customer = new Customer
                {
                    FirstName = "ValidationTest", LastName = "Customer", SSN = TestSSN,
                    CreditScore = 700, AnnualIncome = 75000m, Email = "validation@example.com",
                    Phone = "555-000-0001", Address = "123 Test Street, TestCity, TS 00000",
                    DateOfBirth = new DateTime(1990, 1, 1)
                };

                int newId = _customerService.CreateCustomer(customer);
                LastCreatedCustomerId = newId;
                sw.Stop();

                if (newId <= 0)
                    return Fail(sw, "Create Customer", "Creates a new customer via the service layer and verifies the returned ID is valid", "Customer ID > 0", "Customer ID = " + newId, stage);

                var retrieved = _customerService.GetById(newId);
                if (retrieved == null)
                    return Fail(sw, "Create Customer", "Creates a new customer via the service layer and verifies the returned ID is valid", "Customer retrievable by ID", "Customer not found after creation", stage);

                return Pass(sw, "Create Customer", "Creates a new customer via the service layer and verifies the returned ID is valid", "Customer created with ID=" + newId);
            }
            catch (Exception ex) { sw.Stop(); return Fail(sw, "Create Customer", "Creates a new customer via the service layer and verifies the returned ID is valid", "Customer created", "Exception: " + ex.Message, stage); }
        }

        private TestResult TestRetrieveCustomer(ModernizationStage stage)
        {
            var sw = Stopwatch.StartNew();
            try
            {
                var customer = _customerService.GetById(1);
                sw.Stop();

                if (customer == null)
                    return Fail(sw, "Retrieve Customer", "Retrieves an existing customer by ID and verifies the returned data is valid", "Customer with ID=1 exists", "Customer not found", stage);

                if (string.IsNullOrWhiteSpace(customer.FirstName) || string.IsNullOrWhiteSpace(customer.LastName))
                    return Fail(sw, "Retrieve Customer", "Retrieves an existing customer by ID and verifies the returned data is valid", "Valid customer fields", "Name fields are empty", stage);

                return Pass(sw, "Retrieve Customer", "Retrieves an existing customer by ID and verifies the returned data is valid", "Customer ID=1: " + customer.FirstName + " " + customer.LastName);
            }
            catch (Exception ex) { sw.Stop(); return Fail(sw, "Retrieve Customer", "Retrieves an existing customer by ID and verifies the returned data is valid", "Customer retrieved", "Exception: " + ex.Message, stage); }
        }

        private TestResult TestUpdateCustomer(ModernizationStage stage)
        {
            var sw = Stopwatch.StartNew();
            try
            {
                if (LastCreatedCustomerId <= 0)
                    return Fail(sw, "Update Customer", "Updates a customer's AnnualIncome and CreditScore, then verifies changes persisted", "Test customer exists", "Create Customer test must pass first", stage);

                var toUpdate = _customerService.GetById(LastCreatedCustomerId);
                toUpdate.AnnualIncome = 120000m;
                toUpdate.CreditScore = 780;
                _customerService.UpdateCustomer(toUpdate);

                var updated = _customerService.GetById(LastCreatedCustomerId);
                sw.Stop();

                if (updated.AnnualIncome != 120000m || updated.CreditScore != 780)
                    return Fail(sw, "Update Customer", "Updates a customer's AnnualIncome and CreditScore, then verifies changes persisted", "AnnualIncome=120000, CreditScore=780", "AnnualIncome=" + updated.AnnualIncome + ", CreditScore=" + updated.CreditScore, stage);

                return Pass(sw, "Update Customer", "Updates a customer's AnnualIncome and CreditScore, then verifies changes persisted", "AnnualIncome=120000, CreditScore=780");
            }
            catch (Exception ex) { sw.Stop(); return Fail(sw, "Update Customer", "Updates a customer's AnnualIncome and CreditScore, then verifies changes persisted", "Customer updated", "Exception: " + ex.Message, stage); }
        }

        private TestResult TestSearchCustomer(ModernizationStage stage)
        {
            var sw = Stopwatch.StartNew();
            try
            {
                var results = _customerService.Search("Smith");
                sw.Stop();
                var resultList = results != null ? results.ToList() : new List<Customer>();

                if (resultList.Count == 0)
                    return Fail(sw, "Search Customer", "Searches for customers by name and verifies matching results are returned", "At least one customer matching 'Smith'", "No results returned", stage);

                return Pass(sw, "Search Customer", "Searches for customers by name and verifies matching results are returned", resultList.Count + " customer(s) found");
            }
            catch (Exception ex) { sw.Stop(); return Fail(sw, "Search Customer", "Searches for customers by name and verifies matching results are returned", "Search returns results", "Exception: " + ex.Message, stage); }
        }

        private TestResult Pass(Stopwatch sw, string name, string desc, string actual)
        {
            return new TestResult { TestName = name, Category = CategoryName, Description = desc, Passed = true, Expected = actual, Actual = actual, WhatToCheck = string.Empty, Duration = sw.Elapsed };
        }

        private TestResult Fail(Stopwatch sw, string name, string desc, string expected, string actual, ModernizationStage stage)
        {
            return new TestResult { TestName = name, Category = CategoryName, Description = desc, Passed = false, Expected = expected, Actual = actual, WhatToCheck = GetHint(stage), Duration = sw.Elapsed };
        }

        private static string GetHint(ModernizationStage stage)
        {
            switch (stage)
            {
                case ModernizationStage.PreModernization: return "Check that SQL Server stored procedures are accessible and the service layer is configured correctly";
                case ModernizationStage.PostModule1: return "Check that the service layer works with Aurora PostgreSQL";
                case ModernizationStage.PostModule2: return "Check that EF Core migrations are applied and the Npgsql provider is configured";
                case ModernizationStage.PostModule3: return "Check that the container can reach Aurora PostgreSQL";
                default: return "Check that the service layer and database connection are configured correctly";
            }
        }
    }
}

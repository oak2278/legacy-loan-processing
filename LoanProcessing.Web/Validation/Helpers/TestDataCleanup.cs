using System;
using System.Collections.Generic;

namespace LoanProcessing.Web.Validation.Helpers
{
    /// <summary>
    /// Best-effort cleanup helper for test-created data. Deletes in correct
    /// foreign key order (payment_schedules → loan_decisions → loan_applications → customers)
    /// and swallows exceptions so cleanup failures never fail tests.
    /// </summary>
    public class TestDataCleanup
    {
        private readonly DatabaseHelper _db;

        public TestDataCleanup(DatabaseHelper databaseHelper)
        {
            _db = databaseHelper;
        }

        /// <summary>
        /// Deletes a customer and all related records (loan applications, decisions, payment schedules).
        /// Best-effort — exceptions are swallowed.
        /// </summary>
        public void CleanupCustomer(int customerId)
        {
            // Find all loan applications for this customer so we can clean their children first
            var loanAppIds = new List<int>();
            try
            {
                string loanAppTable = _db.MapTableName("LoanApplications");
                string customerIdCol = _db.MapColumnName("CustomerId");
                string loanAppIdCol = _db.MapColumnName("LoanApplicationId");
                string sql = string.Format(
                    "SELECT {0} FROM dbo.{1} WHERE {2} = @customerId",
                    loanAppIdCol, loanAppTable, customerIdCol);

                var result = _db.ExecuteQuery(sql, ("@customerId", customerId));
                foreach (System.Data.DataRow row in result.Rows)
                {
                    loanAppIds.Add(Convert.ToInt32(row[0]));
                }
            }
            catch
            {
                // Best-effort: if we can't find loan apps, continue with direct deletes
            }

            // Clean up each loan application's children
            foreach (int loanAppId in loanAppIds)
            {
                DeletePaymentSchedules(loanAppId);
                DeleteLoanDecisions(loanAppId);
            }

            // Delete loan applications for this customer
            try
            {
                string loanAppTable = _db.MapTableName("LoanApplications");
                string customerIdCol = _db.MapColumnName("CustomerId");
                string sql = string.Format(
                    "DELETE FROM dbo.{0} WHERE {1} = @customerId",
                    loanAppTable, customerIdCol);

                _db.ExecuteNonQuery(sql, ("@customerId", customerId));
            }
            catch
            {
                // Best-effort
            }

            // Delete the customer
            try
            {
                string customerTable = _db.MapTableName("Customers");
                string customerIdCol = _db.MapColumnName("CustomerId");
                string sql = string.Format(
                    "DELETE FROM dbo.{0} WHERE {1} = @customerId",
                    customerTable, customerIdCol);

                _db.ExecuteNonQuery(sql, ("@customerId", customerId));
            }
            catch
            {
                // Best-effort
            }
        }

        /// <summary>
        /// Deletes a loan application and its related decisions and payment schedules.
        /// Best-effort — exceptions are swallowed.
        /// </summary>
        public void CleanupLoanApplication(int loanApplicationId)
        {
            DeletePaymentSchedules(loanApplicationId);
            DeleteLoanDecisions(loanApplicationId);

            try
            {
                string loanAppTable = _db.MapTableName("LoanApplications");
                string loanAppIdCol = _db.MapColumnName("LoanApplicationId");
                string sql = string.Format(
                    "DELETE FROM dbo.{0} WHERE {1} = @loanAppId",
                    loanAppTable, loanAppIdCol);

                _db.ExecuteNonQuery(sql, ("@loanAppId", loanApplicationId));
            }
            catch
            {
                // Best-effort
            }
        }

        /// <summary>
        /// Batch cleanup of multiple customers and loan applications.
        /// Best-effort — exceptions are swallowed per item.
        /// </summary>
        public void CleanupAll(List<int> customerIds, List<int> loanApplicationIds)
        {
            if (loanApplicationIds != null)
            {
                foreach (int loanAppId in loanApplicationIds)
                {
                    CleanupLoanApplication(loanAppId);
                }
            }

            if (customerIds != null)
            {
                foreach (int customerId in customerIds)
                {
                    CleanupCustomer(customerId);
                }
            }
        }

        /// <summary>
        /// Removes ALL test-created data by SSN prefix (e.g., "999-").
        /// Call this BEFORE creating test data to ensure a clean slate,
        /// regardless of whether previous cleanup succeeded.
        /// Best-effort — exceptions are swallowed.
        /// </summary>
        public void CleanupBySSNPrefix(string ssnPrefix)
        {
            try
            {
                string customerTable = _db.MapTableName("Customers");
                string loanAppTable = _db.MapTableName("LoanApplications");
                string loanDecTable = _db.MapTableName("LoanDecisions");
                string paySchedTable = _db.MapTableName("PaymentSchedules");
                string customerIdCol = _db.MapColumnName("CustomerId");
                string ssnCol = _db.MapColumnName("SSN");
                // FK column in PaymentSchedules and LoanDecisions is ApplicationId, not LoanApplicationId
                string appIdCol = _db.IsPostgreSQL ? "application_id" : "ApplicationId";

                string deletePayments = string.Format(
                    "DELETE FROM dbo.{0} WHERE {1} IN (SELECT la.{1} FROM dbo.{2} la INNER JOIN dbo.{3} c ON la.{4} = c.{4} WHERE c.{5} LIKE @prefix)",
                    paySchedTable, appIdCol, loanAppTable, customerTable, customerIdCol, ssnCol);
                _db.ExecuteNonQuery(deletePayments, ("@prefix", ssnPrefix + "%"));

                string deleteDecisions = string.Format(
                    "DELETE FROM dbo.{0} WHERE {1} IN (SELECT la.{1} FROM dbo.{2} la INNER JOIN dbo.{3} c ON la.{4} = c.{4} WHERE c.{5} LIKE @prefix)",
                    loanDecTable, appIdCol, loanAppTable, customerTable, customerIdCol, ssnCol);
                _db.ExecuteNonQuery(deleteDecisions, ("@prefix", ssnPrefix + "%"));

                string deleteApps = string.Format(
                    "DELETE FROM dbo.{0} WHERE {1} IN (SELECT {1} FROM dbo.{2} WHERE {3} LIKE @prefix)",
                    loanAppTable, customerIdCol, customerTable, ssnCol);
                _db.ExecuteNonQuery(deleteApps, ("@prefix", ssnPrefix + "%"));

                string deleteCustomers = string.Format(
                    "DELETE FROM dbo.{0} WHERE {1} LIKE @prefix",
                    customerTable, ssnCol);
                _db.ExecuteNonQuery(deleteCustomers, ("@prefix", ssnPrefix + "%"));
            }
            catch
            {
                // Best-effort cleanup
            }
        }

        private void DeletePaymentSchedules(int loanApplicationId)
        {
            try
            {
                string table = _db.MapTableName("PaymentSchedules");
                string col = _db.IsPostgreSQL ? "application_id" : "ApplicationId";
                string sql = string.Format(
                    "DELETE FROM dbo.{0} WHERE {1} = @loanAppId",
                    table, col);

                _db.ExecuteNonQuery(sql, ("@loanAppId", loanApplicationId));
            }
            catch
            {
                // Best-effort
            }
        }

        private void DeleteLoanDecisions(int loanApplicationId)
        {
            try
            {
                string table = _db.MapTableName("LoanDecisions");
                string col = _db.IsPostgreSQL ? "application_id" : "ApplicationId";
                string sql = string.Format(
                    "DELETE FROM dbo.{0} WHERE {1} = @loanAppId",
                    table, col);

                _db.ExecuteNonQuery(sql, ("@loanAppId", loanApplicationId));
            }
            catch
            {
                // Best-effort
            }
        }
    }
}

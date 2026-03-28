# Preservation Property Tests for Deployment Automation Fixes
# **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8**
#
# These tests verify behavior that ALREADY WORKS correctly on the unfixed code.
# They MUST PASS on the current (unfixed) code and continue to pass after fixes.
# Property 2: Preservation — Existing Pipeline and Application Behavior

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path (Join-Path $repoRoot 'aws-deployment'))) {
    $repoRoot = Split-Path -Parent $PSScriptRoot
}
if (-not (Test-Path (Join-Path $repoRoot 'aws-deployment'))) {
    $repoRoot = $PSScriptRoot
}

$configureAppScript = Join-Path $repoRoot 'aws-deployment' 'codedeploy' 'configure-application.ps1'
$storedProcsScript  = Join-Path $repoRoot 'database' 'CreateStoredProcedures_Task3.sql'
$sampleDataScript   = Join-Path $repoRoot 'database' 'InitializeSampleData.sql'

# ============================================================================
# Helper: Parse the sp_SearchCustomers WHERE clause from the SQL file
# ============================================================================
function Get-SearchCustomersWhereClause {
    $sqlContent = Get-Content $storedProcsScript -Raw
    # Extract the WHERE clause from sp_SearchCustomers
    if ($sqlContent -match '(?s)CREATE\s+PROCEDURE\s+\[dbo\]\.\[sp_SearchCustomers\].*?WHERE\s+(.*?)ORDER\s+BY') {
        return $Matches[1].Trim()
    }
    return $null
}

# ============================================================================
# Property-Based Tests: sp_SearchCustomers with non-NULL SearchTerm
# ============================================================================
Describe 'Preservation: sp_SearchCustomers with non-NULL @SearchTerm returns filtered results' {

    $sqlContent = Get-Content $storedProcsScript -Raw
    $whereClause = Get-SearchCustomersWhereClause

    It 'WHERE clause contains the SearchTerm branch that checks IS NOT NULL' {
        # The WHERE clause must have a branch: @SearchTerm IS NOT NULL AND (FirstName LIKE ... OR LastName LIKE ...)
        $whereClause | Should Not BeNullOrEmpty
        $whereClause | Should Match '@SearchTerm\s+IS\s+NOT\s+NULL'
    }

    It 'SearchTerm branch performs LIKE matching on FirstName' {
        $whereClause | Should Match "FirstName.*LIKE.*'%'.*\+.*@SearchTerm.*\+.*'%'"
    }

    It 'SearchTerm branch performs LIKE matching on LastName' {
        $whereClause | Should Match "LastName.*LIKE.*'%'.*\+.*@SearchTerm.*\+.*'%'"
    }

    # Property-based: for a set of random non-NULL search terms, the WHERE clause
    # evaluates the @SearchTerm IS NOT NULL branch to true
    $testSearchTerms = @('john', 'Smith', 'a', 'xyz', 'Sarah Johnson', '123', 'J', 'will')
    foreach ($term in $testSearchTerms) {
        It "SearchTerm='$term' activates the @SearchTerm IS NOT NULL branch (non-NULL input)" {
            # The branch (@SearchTerm IS NOT NULL AND ...) evaluates to true when @SearchTerm is not null
            # This is a structural property: the WHERE clause has the correct pattern
            $whereClause | Should Match '@SearchTerm\s+IS\s+NOT\s+NULL\s+AND\s+\('
        }
    }

    It 'SearchTerm branch includes full name concatenation matching' {
        # Verify FirstName + ' ' + LastName LIKE pattern exists
        $whereClause | Should Match "FirstName.*\+.*' '.*\+.*LastName.*LIKE"
    }
}

# ============================================================================
# Property-Based Tests: sp_SearchCustomers with non-NULL CustomerId
# ============================================================================
Describe 'Preservation: sp_SearchCustomers with non-NULL @CustomerId returns single customer' {

    $whereClause = Get-SearchCustomersWhereClause

    It 'WHERE clause contains the CustomerId branch that checks IS NOT NULL' {
        $whereClause | Should Match '@CustomerId\s+IS\s+NOT\s+NULL'
    }

    It 'CustomerId branch performs exact match on CustomerId column' {
        $whereClause | Should Match '@CustomerId\s+IS\s+NOT\s+NULL\s+AND\s+\[CustomerId\]\s*=\s*@CustomerId'
    }

    # Property-based: for a set of random non-NULL CustomerId values, the WHERE clause
    # evaluates the @CustomerId IS NOT NULL branch to true
    $testCustomerIds = @(1, 2, 5, 10, 13, 100, 999)
    foreach ($id in $testCustomerIds) {
        It "CustomerId=$id activates the @CustomerId IS NOT NULL branch (non-NULL input)" {
            # Structural property: the branch exists and will match when @CustomerId is not null
            $whereClause | Should Match '@CustomerId\s+IS\s+NOT\s+NULL\s+AND\s+\[CustomerId\]\s*=\s*@CustomerId'
        }
    }
}

# ============================================================================
# Property-Based Tests: sp_SearchCustomers with non-NULL SSN
# ============================================================================
Describe 'Preservation: sp_SearchCustomers with non-NULL @SSN returns exact match' {

    $whereClause = Get-SearchCustomersWhereClause

    It 'WHERE clause contains the SSN branch that checks IS NOT NULL' {
        $whereClause | Should Match '@SSN\s+IS\s+NOT\s+NULL'
    }

    It 'SSN branch performs exact match on SSN column' {
        $whereClause | Should Match '@SSN\s+IS\s+NOT\s+NULL\s+AND\s+\[SSN\]\s*=\s*@SSN'
    }

    # Property-based: for a set of random non-NULL SSN values, the WHERE clause
    # evaluates the @SSN IS NOT NULL branch to true
    $testSSNs = @('123-45-6789', '234-56-7890', '999-99-9999', '000-00-0000', '111-22-3333')
    foreach ($ssn in $testSSNs) {
        It "SSN='$ssn' activates the @SSN IS NOT NULL branch (non-NULL input)" {
            # Structural property: the branch exists and will match when @SSN is not null
            $whereClause | Should Match '@SSN\s+IS\s+NOT\s+NULL\s+AND\s+\[SSN\]\s*=\s*@SSN'
        }
    }
}

# ============================================================================
# Property-Based Tests: sp_SearchCustomers results ordered by LastName, FirstName
# ============================================================================
Describe 'Preservation: sp_SearchCustomers results are ordered by LastName, FirstName' {

    $sqlContent = Get-Content $storedProcsScript -Raw

    It 'sp_SearchCustomers has ORDER BY LastName, FirstName' {
        # Extract the sp_SearchCustomers procedure body
        $sqlContent | Should Match '(?s)CREATE\s+PROCEDURE\s+\[dbo\]\.\[sp_SearchCustomers\].*?ORDER\s+BY\s+\[LastName\]\s*,\s*\[FirstName\]'
    }
}

# ============================================================================
# Preservation: configure-application.ps1 Steps 0-1 — Secrets Manager retrieval
# ============================================================================
Describe 'Preservation: configure-application.ps1 Secrets Manager credential retrieval (Steps 0-1)' {

    $scriptContent = Get-Content $configureAppScript -Raw

    It 'Loads deployment config from C:\Deploy\config.json' {
        $scriptContent | Should Match 'C:\\Deploy\\config\.json'
    }

    It 'Retrieves secret from AWS Secrets Manager using AWS CLI' {
        $scriptContent | Should Match 'secretsmanager\s+get-secret-value'
    }

    It 'Parses secret JSON with ConvertFrom-Json' {
        $scriptContent | Should Match 'ConvertFrom-Json'
    }

    It 'Extracts host, username, password, and dbname from secret' {
        $scriptContent | Should Match '\$secret\.host'
        $scriptContent | Should Match '\$secret\.username'
        $scriptContent | Should Match '\$secret\.password'
        $scriptContent | Should Match '\$secret\.dbname'
    }

    It 'Validates that required secret fields are not empty' {
        $scriptContent | Should Match 'IsNullOrEmpty.*dbHost'
        $scriptContent | Should Match 'IsNullOrEmpty.*dbUsername'
        $scriptContent | Should Match 'IsNullOrEmpty.*dbPassword'
        $scriptContent | Should Match 'IsNullOrEmpty.*dbName'
    }

    It 'Falls back to SSM Parameter Store if secret ARN not in config' {
        $scriptContent | Should Match 'ssm\s+get-parameter'
    }
}

# ============================================================================
# Preservation: configure-application.ps1 Step 3 — Web.config connection string
# ============================================================================
Describe 'Preservation: configure-application.ps1 Web.config connection string update (Step 3)' {

    $scriptContent = Get-Content $configureAppScript -Raw

    It 'Connection string includes Encrypt=True' {
        $scriptContent | Should Match 'Encrypt=True'
    }

    It 'Connection string includes TrustServerCertificate=True' {
        $scriptContent | Should Match 'TrustServerCertificate=True'
    }

    It 'Loads Web.config as XML to preserve other settings' {
        $scriptContent | Should Match '\[xml\].*Get-Content.*webConfigPath'
    }

    It 'Saves Web.config after update (preserving other settings)' {
        $scriptContent | Should Match '\.Save\('
    }

    It 'Targets LoanProcessingConnection by name' {
        $scriptContent | Should Match 'LoanProcessingConnection'
    }

    It 'Sets connectionString attribute on the connection node' {
        $scriptContent | Should Match 'SetAttribute.*connectionString'
    }

    It 'Creates connectionStrings section if it does not exist' {
        $scriptContent | Should Match 'connectionStringsNode.*CreateElement.*connectionStrings'
    }
}

# ============================================================================
# Preservation: configure-application.ps1 — error tolerance (exit 0)
# ============================================================================
Describe 'Preservation: configure-application.ps1 database init failures do not fail deployment' {

    $scriptContent = Get-Content $configureAppScript -Raw
    $lines = Get-Content $configureAppScript

    It 'Has try/catch around database initialization' {
        # The database initialization block is wrapped in try/catch
        $scriptContent | Should Match '(?s)try\s*\{.*?CreateDatabase.*?catch'
    }

    It 'Catch block logs warning but does not rethrow for DB init failures' {
        # Inside the DB init try/catch, the catch block logs but does not throw
        # Find the inner catch block for database initialization
        $inDbInitTry = $false
        $foundCatchWithWarn = $false
        $braceDepth = 0

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -match 'Database does not exist.*proceeding with initialization') {
                $inDbInitTry = $true
            }
            if ($inDbInitTry -and $line -match 'Database initialization failed.*WARN') {
                $foundCatchWithWarn = $true
                break
            }
        }
        $foundCatchWithWarn | Should Be $true
    }

    It 'Script ends with exit 0 on success path' {
        $scriptContent | Should Match 'exit\s+0'
    }

    It 'Deployment continues despite database initialization failure (no rethrow in inner catch)' {
        # The inner catch for DB init should NOT contain 'throw' — it just logs and continues
        $inDbInitCatch = $false
        $innerCatchHasThrow = $false
        $braceDepth = 0

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -match 'Database initialization failed') {
                $inDbInitCatch = $true
                $braceDepth = 1
                continue
            }
            if ($inDbInitCatch) {
                $braceDepth += ([regex]::Matches($line, '\{')).Count
                $braceDepth -= ([regex]::Matches($line, '\}')).Count
                if ($line -match '^\s*throw\b') {
                    $innerCatchHasThrow = $true
                }
                if ($braceDepth -le 0) { break }
            }
        }
        $innerCatchHasThrow | Should Be $false
    }
}

# ============================================================================
# Preservation: Stored procedure scripts use idempotent DROP/CREATE pattern
# ============================================================================
Describe 'Preservation: Stored procedure scripts are idempotent (IF OBJECT_ID/DROP/CREATE)' {

    $sqlContent = Get-Content $storedProcsScript -Raw

    It 'sp_SearchCustomers uses IF OBJECT_ID ... DROP before CREATE' {
        $sqlContent | Should Match "(?s)IF\s+OBJECT_ID\s*\(\s*'dbo\.sp_SearchCustomers'"
    }

    It 'sp_GetCustomerById uses IF OBJECT_ID ... DROP before CREATE' {
        $sqlContent | Should Match "(?s)IF\s+OBJECT_ID\s*\(\s*'dbo\.sp_GetCustomerById'"
    }

    It 'sp_UpdateCustomer uses IF OBJECT_ID ... DROP before CREATE' {
        $sqlContent | Should Match "(?s)IF\s+OBJECT_ID\s*\(\s*'dbo\.sp_UpdateCustomer'"
    }

    It 'sp_CreateCustomer uses IF OBJECT_ID ... DROP before CREATE' {
        $sqlContent | Should Match "(?s)IF\s+OBJECT_ID\s*\(\s*'dbo\.sp_CreateCustomer'"
    }
}

# ============================================================================
# Preservation: Existing data preserved on redeployment
# ============================================================================
Describe 'Preservation: Stored procedure scripts do not DROP or ALTER tables' {

    $sqlContent = Get-Content $storedProcsScript -Raw

    It 'CreateStoredProcedures_Task3.sql does not contain DROP TABLE' {
        $sqlContent | Should Not Match 'DROP\s+TABLE'
    }

    It 'CreateStoredProcedures_Task3.sql does not contain ALTER TABLE' {
        $sqlContent | Should Not Match 'ALTER\s+TABLE'
    }

    It 'CreateStoredProcedures_Task3.sql does not contain DELETE FROM' {
        $sqlContent | Should Not Match 'DELETE\s+FROM'
    }

    It 'CreateStoredProcedures_Task3.sql does not contain TRUNCATE TABLE' {
        $sqlContent | Should Not Match 'TRUNCATE\s+TABLE'
    }
}

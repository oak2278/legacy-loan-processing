# Bug Condition Exploration Tests for Deployment Automation Fixes
# **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10**
#
# These tests encode the EXPECTED (correct) behavior.
# On UNFIXED code, they MUST FAIL — failure confirms the bugs exist.
# After fixes are applied, these same tests should PASS.

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path (Join-Path $repoRoot 'aws-deployment'))) {
    $repoRoot = Split-Path -Parent $PSScriptRoot
}
if (-not (Test-Path (Join-Path $repoRoot 'aws-deployment'))) {
    $repoRoot = $PSScriptRoot
}

$configureAppScript = Join-Path $repoRoot 'aws-deployment' 'codedeploy' 'configure-application.ps1'
$userDataScript     = Join-Path $repoRoot 'aws-deployment' 'terraform' 'modules' 'compute' 'user-data.ps1'
$storedProcsScript  = Join-Path $repoRoot 'database' 'CreateStoredProcedures_Task3.sql'
$sampleDataScript   = Join-Path $repoRoot 'database' 'InitializeSampleData.sql'
$searchAutoScript   = Join-Path $repoRoot 'database' 'CreateSearchCustomersAutocomplete.sql'

Describe 'Bug 1: sqlcmd missing — configure-application.ps1 should use Invoke-Sqlcmd, not sqlcmd' {

    $scriptContent = Get-Content $configureAppScript -Raw

    It 'Should use Invoke-Sqlcmd for database operations instead of sqlcmd' {
        # Expected behavior: script uses Invoke-Sqlcmd (from SqlServer module)
        $scriptContent | Should Match 'Invoke-Sqlcmd'
    }

    It 'Should not contain bare sqlcmd calls for database operations' {
        # Expected behavior: no sqlcmd binary calls remain
        # Match lines that call sqlcmd as a command (not in comments or strings describing the old approach)
        $lines = (Get-Content $configureAppScript) | Where-Object {
            $_ -notmatch '^\s*#' -and $_ -match '\bsqlcmd\b' -and $_ -match '-S\s'
        }
        $lines.Count | Should Be 0
    }

    It 'Should import the SqlServer module' {
        $scriptContent | Should Match 'Import-Module\s+SqlServer'
    }
}

Describe 'Bug 1 (user-data): SqlServer module should be installed during provisioning' {

    $userDataContent = Get-Content $userDataScript -Raw

    It 'Should install the SqlServer PowerShell module in user-data.ps1' {
        # Expected behavior: user-data.ps1 installs SqlServer module so Invoke-Sqlcmd is available
        $userDataContent | Should Match 'Install-Module\s+.*SqlServer'
    }
}

Describe 'Bug 2: Missing stored procedures — all SQL scripts should be executed' {

    $scriptContent = Get-Content $configureAppScript -Raw

    It 'Should reference CreateStoredProcedures_Task3.sql for execution' {
        $scriptContent | Should Match 'CreateStoredProcedures_Task3\.sql'
    }

    It 'Should reference CreateSearchCustomersAutocomplete.sql for execution' {
        $scriptContent | Should Match 'CreateSearchCustomersAutocomplete\.sql'
    }

    It 'Should execute scripts in correct order: CreateDatabase -> StoredProcs -> SearchAutocomplete -> SampleData' {
        # Find line numbers where each script is referenced (non-comment lines)
        $lines = Get-Content $configureAppScript
        $createDbLine = -1
        $storedProcsLine = -1
        $searchAutoLine = -1
        $sampleDataLine = -1

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -notmatch '^\s*#') {
                if ($line -match 'CreateDatabase\.sql' -and $createDbLine -eq -1) { $createDbLine = $i }
                if ($line -match 'CreateStoredProcedures_Task3\.sql' -and $storedProcsLine -eq -1) { $storedProcsLine = $i }
                if ($line -match 'CreateSearchCustomersAutocomplete\.sql' -and $searchAutoLine -eq -1) { $searchAutoLine = $i }
                if ($line -match 'InitializeSampleData\.sql' -and $sampleDataLine -eq -1) { $sampleDataLine = $i }
            }
        }

        # All scripts must be referenced
        $storedProcsLine | Should Not Be -1
        $searchAutoLine | Should Not Be -1

        # Order: CreateDatabase < StoredProcs < SearchAutocomplete < SampleData
        if ($createDbLine -ge 0 -and $storedProcsLine -ge 0) {
            $createDbLine | Should BeLessThan $storedProcsLine
        }
        if ($storedProcsLine -ge 0 -and $searchAutoLine -ge 0) {
            $storedProcsLine | Should BeLessThan $searchAutoLine
        }
        if ($searchAutoLine -ge 0 -and $sampleDataLine -ge 0) {
            $searchAutoLine | Should BeLessThan $sampleDataLine
        }
    }
}

Describe 'Bug 3: Non-idempotent deployment — stored procs should run even when DB exists' {

    $scriptContent = Get-Content $configureAppScript -Raw

    It 'Should execute stored procedure scripts when database already exists (dbExists -eq 1)' {
        # Expected behavior: the else branch (when DB exists) should still reference
        # stored procedure scripts for re-execution.
        # On unfixed code, the else branch just logs "skipping initialization".

        $lines = Get-Content $configureAppScript
        $inElseBranch = $false
        $braceDepth = 0
        $foundStoredProcInElse = $false

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]

            # Detect the else branch for "Database already exists"
            if ($line -match '^\s*\}\s*else\s*\{' -or ($line -match '^\s*else\s*\{')) {
                # Check if previous context is about dbExists (use large lookback for big if-blocks)
                $contextStart = [Math]::Max(0, $i - 100)
                $context = ($lines[$contextStart..$i]) -join "`n"
                if ($context -match 'dbExists') {
                    $inElseBranch = $true
                    $braceDepth = 1
                    continue
                }
            }

            if ($inElseBranch) {
                $braceDepth += ([regex]::Matches($line, '\{')).Count
                $braceDepth -= ([regex]::Matches($line, '\}')).Count

                if ($line -notmatch '^\s*#' -and ($line -match 'CreateStoredProcedures_Task3' -or $line -match 'CreateSearchCustomersAutocomplete')) {
                    $foundStoredProcInElse = $true
                }

                if ($braceDepth -le 0) {
                    break
                }
            }
        }

        $foundStoredProcInElse | Should Be $true
    }
}

Describe 'Bug 4: Blank search returns empty — sp_SearchCustomers should return all rows when all params NULL' {

    $sqlContent = Get-Content $storedProcsScript -Raw

    It 'Should have a WHERE clause branch that handles all-NULL parameters' {
        # Expected behavior: the WHERE clause should include a branch like
        # OR (@SearchTerm IS NULL AND @CustomerId IS NULL AND @SSN IS NULL)
        # that returns all customers when no search criteria are provided.
        #
        # On unfixed code, the WHERE clause only has three branches, each requiring
        # a non-NULL parameter. When all are NULL, zero rows are returned.

        $sqlContent | Should Match '(?s)@SearchTerm\s+IS\s+NULL\s+AND\s+@CustomerId\s+IS\s+NULL\s+AND\s+@SSN\s+IS\s+NULL'
    }
}

Describe 'Bug 5: FK constraint errors — InitializeSampleData.sql identity seeding and FK references' {

    $sqlContent = Get-Content $sampleDataScript -Raw

    It 'Should not use RESEED 0 for LoanApplications (causes first identity = 0, not 1)' {
        # Expected behavior: RESEED should use 1 (or the script should query actual IDs)
        # On unfixed code: DBCC CHECKIDENT('LoanApplications', RESEED, 0) causes
        # first identity = 0, making hardcoded @App7 = 7 reference the wrong row.

        # Check that RESEED 0 is NOT used for LoanApplications
        $hasReseed0 = $sqlContent -match "CHECKIDENT\s*\(\s*'LoanApplications'\s*,\s*RESEED\s*,\s*0\s*\)"
        $hasReseed0 | Should Be $false
    }

    It 'Should not use hardcoded ApplicationId values for LoanDecisions FK references' {
        # Expected behavior: ApplicationId values should be queried from actual inserted data
        # On unfixed code: DECLARE @App7 INT = 7 etc. are hardcoded assumptions

        $hasHardcodedApp7 = $sqlContent -match '@App7\s+(INT\s+)?=\s*7\s*;'
        $hasHardcodedApp7 | Should Be $false
    }

    It 'Should wrap data insertion in a transaction for atomicity' {
        # Expected behavior: BEGIN TRANSACTION / COMMIT with ROLLBACK on error
        # On unfixed code: no transaction wrapping, partial data on failure

        $sqlContent | Should Match 'BEGIN\s+TRAN(SACTION)?'
    }
}

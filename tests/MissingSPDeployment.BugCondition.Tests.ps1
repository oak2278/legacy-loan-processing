# Bug Condition Exploration Tests - Missing Stored Procedures Deployment
# **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7**
#
# Property 1: Bug Condition — Missing 5 Stored Procedures After Deployment
#
# These tests encode the EXPECTED (correct) behavior.
# On UNFIXED code, they MUST FAIL — failure confirms the bugs exist.
# After fixes are applied, these same tests should PASS.

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path (Join-Path $repoRoot 'buildspec.yml'))) {
    $repoRoot = Split-Path -Parent $PSScriptRoot
}
if (-not (Test-Path (Join-Path $repoRoot 'buildspec.yml'))) {
    $repoRoot = $PSScriptRoot
}

$buildspecPath = Join-Path $repoRoot 'buildspec.yml'
$configureAppScript = Join-Path (Join-Path (Join-Path $repoRoot 'aws-deployment') 'codedeploy') 'configure-application.ps1'
$spDirectory = Join-Path (Join-Path $repoRoot 'LoanProcessing.Database') 'StoredProcedures'

$missingSPFiles = @(
    'sp_SubmitLoanApplication.sql',
    'sp_EvaluateCredit.sql',
    'sp_ProcessLoanDecision.sql',
    'sp_CalculatePaymentSchedule.sql',
    'sp_GeneratePortfolioReport.sql'
)

$allTenSPNames = @(
    'sp_SearchCustomers',
    'sp_GetCustomerById',
    'sp_UpdateCustomer',
    'sp_CreateCustomer',
    'sp_SearchCustomersAutocomplete',
    'sp_SubmitLoanApplication',
    'sp_EvaluateCredit',
    'sp_ProcessLoanDecision',
    'sp_CalculatePaymentSchedule',
    'sp_GeneratePortfolioReport'
)

# ============================================================================
# Bug Condition 1: buildspec.yml must copy SP files from
# LoanProcessing.Database\StoredProcedures\
# Validates: Requirement 1.2
# ============================================================================
Describe 'Bug Condition: buildspec.yml copies SP files from LoanProcessing.Database\StoredProcedures\' {

    $buildspecContent = Get-Content $buildspecPath -Raw

    It 'Should contain a copy command for LoanProcessing.Database\StoredProcedures\ SP files to deployment-package\database\' {
        $buildspecContent | Should Match 'LoanProcessing\.Database\\StoredProcedures\\'
    }

    # Property-based: for each of the 5 SP files, the buildspec should reference them
    foreach ($spFile in $missingSPFiles) {
        It "Should include a command that copies $spFile into the deployment package" {
            $pattern = [regex]::Escape($spFile)
            $buildspecContent | Should Match $pattern
        }
    }
}

# ============================================================================
# Bug Condition 2: configure-application.ps1 must invoke all 5 SP scripts
# in BOTH the fresh-install and redeployment branches
# Validates: Requirements 1.1, 1.3, 1.4, 1.5, 1.6, 1.7
# ============================================================================
Describe 'Bug Condition: configure-application.ps1 invokes all 5 SP scripts in fresh-install branch' {

    $lines = Get-Content $configureAppScript

    # Find the fresh-install branch (where $dbExists -eq 0)
    $inFreshInstall = $false
    $braceDepth = 0
    $freshInstallContent = ''

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '\$dbExists\s+-eq\s+0') {
            $inFreshInstall = $true
            $braceDepth = 0
        }
        if ($inFreshInstall) {
            $braceDepth += ([regex]::Matches($line, '\{')).Count
            $braceDepth -= ([regex]::Matches($line, '\}')).Count
            $freshInstallContent += $line + "`n"
            if ($braceDepth -le 0 -and $freshInstallContent.Length -gt 10) {
                break
            }
        }
    }

    foreach ($spFile in $missingSPFiles) {
        It "Fresh-install branch should contain Invoke-Sqlcmd referencing $spFile" {
            $pattern = [regex]::Escape($spFile)
            $freshInstallContent | Should Match $pattern
        }
    }
}

Describe 'Bug Condition: configure-application.ps1 invokes all 5 SP scripts in redeployment branch' {

    $lines = Get-Content $configureAppScript

    # Find the else branch (redeployment - when DB already exists)
    $inElseBranch = $false
    $braceDepth = 0
    $elseContent = ''
    $foundDbExistsIf = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '\$dbExists\s+-eq\s+0') {
            $foundDbExistsIf = $true
        }
        if ($foundDbExistsIf -and -not $inElseBranch -and ($line -match '^\s*\}\s*else\s*\{' -or $line -match '^\s*else\s*\{')) {
            $inElseBranch = $true
            $braceDepth = 1
            continue
        }
        if ($inElseBranch) {
            $braceDepth += ([regex]::Matches($line, '\{')).Count
            $braceDepth -= ([regex]::Matches($line, '\}')).Count
            $elseContent += $line + "`n"
            if ($braceDepth -le 0) {
                break
            }
        }
    }

    foreach ($spFile in $missingSPFiles) {
        It "Redeployment branch should contain Invoke-Sqlcmd referencing $spFile" {
            $pattern = [regex]::Escape($spFile)
            $elseContent | Should Match $pattern
        }
    }
}

# ============================================================================
# Bug Condition 3: Each SP file must have IF OBJECT_ID / DROP PROCEDURE
# idempotency guards before CREATE PROCEDURE
# Validates: Requirement 2.8 (idempotency for redeployment)
# ============================================================================
Describe 'Bug Condition: SP files contain idempotency guards (IF OBJECT_ID / DROP PROCEDURE)' {

    foreach ($spFile in $missingSPFiles) {
        $spPath = Join-Path $spDirectory $spFile
        $spContent = Get-Content $spPath -Raw
        $spName = [System.IO.Path]::GetFileNameWithoutExtension($spFile)

        It "$spFile should contain IF OBJECT_ID guard before CREATE PROCEDURE" {
            $spContent | Should Match 'IF\s+OBJECT_ID\s*\('
        }

        It "$spFile should contain DROP PROCEDURE before CREATE PROCEDURE" {
            $spContent | Should Match 'DROP\s+PROCEDURE'
        }

        It "$spFile should have the guard appear BEFORE CREATE PROCEDURE" {
            $objectIdPos = $spContent.IndexOf('IF OBJECT_ID')
            $createPos = $spContent.IndexOf('CREATE PROCEDURE')
            $objectIdPos | Should Not Be -1
            $objectIdPos | Should BeLessThan $createPos
        }
    }
}

# ============================================================================
# Bug Condition 4: Verification query must check for all 10 stored procedures
# Validates: Requirement 2.1
# ============================================================================
Describe 'Bug Condition: Verification query checks for all 10 stored procedures' {

    $scriptContent = Get-Content $configureAppScript -Raw

    foreach ($spName in $allTenSPNames) {
        It "Verification query should reference $spName" {
            $pattern = [regex]::Escape($spName)
            $scriptContent | Should Match "verifyProcsQuery.*(?s).*$pattern"
        }
    }

    It 'Verification should check for count of 10 (not 5)' {
        $scriptContent | Should Match 'Verified.*\$procCount/10'
    }
}

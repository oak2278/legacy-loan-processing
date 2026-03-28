# Preservation Property Tests - Missing Stored Procedures Deployment
# **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6**
#
# Property 2: Preservation — Existing Deployment Behavior Unchanged
#
# These tests verify behavior that ALREADY WORKS correctly on the unfixed code.
# They MUST PASS on the current (unfixed) code and continue to pass after fixes.
# Observation-first methodology: assertions derived from observing unfixed code.

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path (Join-Path $repoRoot 'buildspec.yml'))) {
    $repoRoot = Split-Path -Parent $PSScriptRoot
}
if (-not (Test-Path (Join-Path $repoRoot 'buildspec.yml'))) {
    $repoRoot = $PSScriptRoot
}

$buildspecPath = Join-Path $repoRoot 'buildspec.yml'
$configureAppScript = Join-Path (Join-Path (Join-Path $repoRoot 'aws-deployment') 'codedeploy') 'configure-application.ps1'
$appspecPath = Join-Path (Join-Path $repoRoot 'aws-deployment') 'appspec.yml'

# ============================================================================
# Preservation 1: buildspec.yml still contains xcopy commands for existing assets
# Validates: Requirement 3.6
# ============================================================================
Describe 'Preservation: buildspec.yml retains existing xcopy commands for database scripts' {

    $buildspecContent = Get-Content $buildspecPath -Raw

    It 'Should contain xcopy for database\*.sql to deployment-package\database\' {
        $buildspecContent | Should Match 'xcopy\s+database\\\*\.sql\s+deployment-package\\database\\'
    }
}

Describe 'Preservation: buildspec.yml retains existing xcopy commands for web app files' {

    $buildspecContent = Get-Content $buildspecPath -Raw

    It 'Should contain xcopy for LoanProcessing.Web\bin' {
        $buildspecContent | Should Match 'xcopy\s+LoanProcessing\.Web\\bin\s+deployment-package\\app\\bin\\'
    }

    It 'Should contain xcopy for LoanProcessing.Web\Content' {
        $buildspecContent | Should Match 'xcopy\s+LoanProcessing\.Web\\Content\s+deployment-package\\app\\Content\\'
    }

    It 'Should contain xcopy for LoanProcessing.Web\fonts' {
        $buildspecContent | Should Match 'xcopy\s+LoanProcessing\.Web\\fonts\s+deployment-package\\app\\fonts\\'
    }

    It 'Should contain xcopy for LoanProcessing.Web\Scripts' {
        $buildspecContent | Should Match 'xcopy\s+LoanProcessing\.Web\\Scripts\s+deployment-package\\app\\Scripts\\'
    }

    It 'Should contain xcopy for LoanProcessing.Web\Views' {
        $buildspecContent | Should Match 'xcopy\s+LoanProcessing\.Web\\Views\s+deployment-package\\app\\Views\\'
    }

    It 'Should contain copy for Global.asax' {
        $buildspecContent | Should Match 'copy\s+LoanProcessing\.Web\\Global\.asax\s+deployment-package\\app\\'
    }

    It 'Should contain copy for Web.config' {
        $buildspecContent | Should Match 'copy\s+LoanProcessing\.Web\\Web\.config\s+deployment-package\\app\\'
    }
}

Describe 'Preservation: buildspec.yml retains existing xcopy commands for CodeDeploy scripts and appspec.yml' {

    $buildspecContent = Get-Content $buildspecPath -Raw

    It 'Should contain xcopy for aws-deployment\codedeploy\*.ps1 to deployment-package\scripts\' {
        $buildspecContent | Should Match 'xcopy\s+aws-deployment\\codedeploy\\\*\.ps1\s+deployment-package\\scripts\\'
    }

    It 'Should contain copy for aws-deployment\appspec.yml to deployment-package\' {
        $buildspecContent | Should Match 'copy\s+aws-deployment\\appspec\.yml\s+deployment-package\\'
    }
}

# ============================================================================
# Preservation 2: configure-application.ps1 fresh-install branch invokes
# existing scripts in correct order
# Validates: Requirements 3.1, 3.2, 3.3
# ============================================================================
Describe 'Preservation: configure-application.ps1 fresh-install branch invokes existing SQL scripts' {

    $lines = Get-Content $configureAppScript

    # Extract the fresh-install branch content (where $dbExists -eq 0)
    $inFreshInstall = $false
    $braceDepth = 0
    $freshInstallLines = @()

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '\$dbExists\s+-eq\s+0') {
            $inFreshInstall = $true
            $braceDepth = 0
        }
        if ($inFreshInstall) {
            $braceDepth += ([regex]::Matches($line, '\{')).Count
            $braceDepth -= ([regex]::Matches($line, '\}')).Count
            $freshInstallLines += $line
            if ($braceDepth -le 0 -and $freshInstallLines.Count -gt 2) {
                break
            }
        }
    }
    $freshInstallContent = $freshInstallLines -join "`n"

    It 'Fresh-install branch should invoke CreateDatabase.sql' {
        $freshInstallContent | Should Match 'CreateDatabase\.sql'
    }

    It 'Fresh-install branch should invoke CreateStoredProcedures_Task3.sql' {
        $freshInstallContent | Should Match 'CreateStoredProcedures_Task3\.sql'
    }

    It 'Fresh-install branch should invoke CreateSearchCustomersAutocomplete.sql' {
        $freshInstallContent | Should Match 'CreateSearchCustomersAutocomplete\.sql'
    }

    It 'Fresh-install branch should invoke InitializeSampleData.sql' {
        $freshInstallContent | Should Match 'InitializeSampleData\.sql'
    }

    It 'Fresh-install branch should invoke scripts in correct order: CreateDatabase -> StoredProcs -> SearchAutocomplete -> SampleData' {
        # Find positions of each script reference in the fresh-install content (non-comment lines only)
        $createDbPos = -1
        $storedProcsPos = -1
        $searchAutoPos = -1
        $sampleDataPos = -1

        for ($i = 0; $i -lt $freshInstallLines.Count; $i++) {
            $line = $freshInstallLines[$i]
            if ($line -notmatch '^\s*#') {
                if ($line -match 'CreateDatabase\.sql' -and $createDbPos -eq -1) { $createDbPos = $i }
                if ($line -match 'CreateStoredProcedures_Task3\.sql' -and $storedProcsPos -eq -1) { $storedProcsPos = $i }
                if ($line -match 'CreateSearchCustomersAutocomplete\.sql' -and $searchAutoPos -eq -1) { $searchAutoPos = $i }
                if ($line -match 'InitializeSampleData\.sql' -and $sampleDataPos -eq -1) { $sampleDataPos = $i }
            }
        }

        $createDbPos | Should Not Be -1
        $storedProcsPos | Should Not Be -1
        $searchAutoPos | Should Not Be -1
        $sampleDataPos | Should Not Be -1

        $createDbPos | Should BeLessThan $storedProcsPos
        $storedProcsPos | Should BeLessThan $searchAutoPos
        $searchAutoPos | Should BeLessThan $sampleDataPos
    }
}

# ============================================================================
# Preservation 3: configure-application.ps1 redeployment branch invokes
# existing SP scripts
# Validates: Requirement 3.4
# ============================================================================
Describe 'Preservation: configure-application.ps1 redeployment branch invokes existing SP scripts' {

    $lines = Get-Content $configureAppScript

    # Extract the else branch (redeployment - when DB already exists)
    $inElseBranch = $false
    $braceDepth = 0
    $elseLines = @()
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
            $elseLines += $line
            if ($braceDepth -le 0) {
                break
            }
        }
    }
    $elseContent = $elseLines -join "`n"

    It 'Redeployment branch should invoke CreateStoredProcedures_Task3.sql' {
        $elseContent | Should Match 'CreateStoredProcedures_Task3\.sql'
    }

    It 'Redeployment branch should invoke CreateSearchCustomersAutocomplete.sql' {
        $elseContent | Should Match 'CreateSearchCustomersAutocomplete\.sql'
    }
}

# ============================================================================
# Preservation 4: configure-application.ps1 Web.config connection string
# configuration logic (LoanProcessingConnection)
# Validates: Requirement 3.5
# ============================================================================
Describe 'Preservation: configure-application.ps1 Web.config connection string configuration' {

    $scriptContent = Get-Content $configureAppScript -Raw

    It 'Should reference LoanProcessingConnection connection string name' {
        $scriptContent | Should Match 'LoanProcessingConnection'
    }

    It 'Should load Web.config as XML' {
        $scriptContent | Should Match '\[xml\].*Get-Content.*webConfigPath'
    }

    It 'Should set connectionString attribute on the connection node' {
        $scriptContent | Should Match 'SetAttribute.*connectionString'
    }

    It 'Should save Web.config after update' {
        $scriptContent | Should Match '\.Save\(.*webConfigPath\)'
    }

    It 'Should create connectionStrings section if it does not exist' {
        $scriptContent | Should Match 'CreateElement.*connectionStrings'
    }

    It 'Should build connection string with Server, Database, User Id, Password' {
        $scriptContent | Should Match 'Server=\$dbHost;Database=\$dbName;User Id=\$dbUsername;Password=\$dbPassword'
    }
}

# ============================================================================
# Preservation 5: configure-application.ps1 error handling and logging patterns
# Validates: Requirement 3.5 (deployment behavior unchanged)
# ============================================================================
Describe 'Preservation: configure-application.ps1 error handling and logging patterns' {

    $scriptContent = Get-Content $configureAppScript -Raw
    $lines = Get-Content $configureAppScript

    It 'Should set ErrorActionPreference to Stop' {
        $scriptContent | Should Match '\$ErrorActionPreference\s*=\s*"Stop"'
    }

    It 'Should define Write-DeploymentLog function' {
        $scriptContent | Should Match 'function\s+Write-DeploymentLog'
    }

    It 'Should define Write-SafeLog function for redacting sensitive info' {
        $scriptContent | Should Match 'function\s+Write-SafeLog'
    }

    It 'Should have try/catch around database initialization' {
        $scriptContent | Should Match '(?s)try\s*\{.*?CreateDatabase.*?catch'
    }

    It 'Database init catch block logs warning but does not rethrow' {
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

    It 'Script ends with exit 0 on success path' {
        $scriptContent | Should Match 'exit\s+0'
    }

    It 'Script ends with exit 1 on fatal error path' {
        $scriptContent | Should Match 'exit\s+1'
    }

    It 'Fatal error catch block logs ERROR level' {
        $scriptContent | Should Match 'Fatal error in AfterInstall hook.*ERROR'
    }
}

# ============================================================================
# Preservation 6: CodeDeploy lifecycle hook ordering (Steps 0-6 structure)
# Validates: Requirement 3.6
# ============================================================================
Describe 'Preservation: configure-application.ps1 CodeDeploy lifecycle hook ordering (Steps 0-6)' {

    $scriptContent = Get-Content $configureAppScript -Raw
    $lines = Get-Content $configureAppScript

    It 'Should contain STEP 0: Load Deployment Config' {
        $scriptContent | Should Match 'STEP 0.*Load Deployment Config'
    }

    It 'Should contain STEP 1: Retrieve Database Credentials' {
        $scriptContent | Should Match 'STEP 1.*Retrieve Database Credentials'
    }

    It 'Should contain STEP 2: Build SQL Server Connection String' {
        $scriptContent | Should Match 'STEP 2.*Build SQL Server Connection String'
    }

    It 'Should contain STEP 3: Update Web.config with Connection String' {
        $scriptContent | Should Match 'STEP 3.*Update Web\.config'
    }

    It 'Should contain STEP 4: Check if Database Exists' {
        $scriptContent | Should Match 'STEP 4.*Check if Database Exists'
    }

    It 'Should contain STEP 5: Initialize Database if Needed' {
        $scriptContent | Should Match 'STEP 5.*Initialize Database'
    }

    It 'Should contain STEP 6: Verify Configuration' {
        $scriptContent | Should Match 'STEP 6.*Verify Configuration'
    }

    It 'Steps should appear in order 0 through 6' {
        $stepPositions = @()
        for ($step = 0; $step -le 6; $step++) {
            $pattern = "STEP $step"
            $pos = $scriptContent.IndexOf($pattern)
            $pos | Should Not Be -1
            $stepPositions += $pos
        }

        for ($i = 1; $i -lt $stepPositions.Count; $i++) {
            $stepPositions[$i] | Should BeGreaterThan $stepPositions[$i - 1]
        }
    }
}

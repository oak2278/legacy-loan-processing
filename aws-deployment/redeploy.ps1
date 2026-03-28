# redeploy.ps1
# Tears down the EC2 instance and redeploys with updated user-data.ps1
# Run from the repo root: .\aws-deployment\redeploy.ps1

param(
    [switch]$SkipDestroy,
    [switch]$AutoApprove
)

$ErrorActionPreference = "Stop"
$tfDir = Join-Path $PSScriptRoot "terraform"

Write-Host "=== Deployment Automation Fixes - Redeploy ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Commit and push changes
Write-Host "[1/4] Checking for uncommitted changes..." -ForegroundColor Yellow
$status = git status --porcelain
if ($status) {
    Write-Host "  Uncommitted changes found. Committing..." -ForegroundColor Yellow
    git add -A
    git commit -m "fix: deployment automation - replace sqlcmd with Invoke-Sqlcmd, add stored procs, fix blank search, fix FK constraints"
    git push origin main
    Write-Host "  Changes pushed to main." -ForegroundColor Green
} else {
    Write-Host "  Working tree clean." -ForegroundColor Green
}

# Step 2: Terraform destroy (to get fresh user-data)
if (-not $SkipDestroy) {
    Write-Host ""
    Write-Host "[2/4] Destroying infrastructure (fresh user-data requires new instance)..." -ForegroundColor Yellow
    $destroyArgs = @("-auto-approve")
    if (-not $AutoApprove) {
        Write-Host "  This will destroy all AWS resources. Press Ctrl+C to cancel, or wait 10 seconds..." -ForegroundColor Red
        Start-Sleep -Seconds 10
    }
    Push-Location $tfDir
    terraform destroy -auto-approve
    Pop-Location
    Write-Host "  Infrastructure destroyed." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[2/4] Skipping destroy (--SkipDestroy flag set)." -ForegroundColor DarkYellow
}

# Step 3: Terraform apply
Write-Host ""
Write-Host "[3/4] Applying infrastructure (new instance with SqlServer module)..." -ForegroundColor Yellow
Push-Location $tfDir
terraform apply -auto-approve
Pop-Location
Write-Host "  Infrastructure created." -ForegroundColor Green

# Step 4: Wait for pipeline
Write-Host ""
Write-Host "[4/4] Infrastructure is up. The CodePipeline will trigger automatically from the push." -ForegroundColor Yellow
Write-Host ""
Write-Host "=== Next steps ===" -ForegroundColor Cyan
Write-Host "  1. Monitor the pipeline in the AWS Console (CodePipeline)"
Write-Host "  2. Once deployed, verify: blank search returns all customers"
Write-Host "  3. Verify: search with term still returns filtered results"
Write-Host "  4. Push again to test idempotent redeployment"
Write-Host ""

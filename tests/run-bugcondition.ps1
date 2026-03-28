$r = Invoke-Pester -Path 'tests/MissingSPDeployment.BugCondition.Tests.ps1' -PassThru
foreach ($t in $r.TestResult) {
    Write-Host ("{0} : {1}" -f $t.Result, $t.Name)
}
Write-Host ""
Write-Host ("TOTAL: {0} Passed: {1} Failed: {2}" -f $r.TotalCount, $r.PassedCount, $r.FailedCount)

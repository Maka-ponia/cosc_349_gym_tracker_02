$ErrorActionPreference = "Stop"

Write-Host "Checking virtual machines..."

$status = vagrant status --machine-readable

$vms = @(
    "frontend",
    "backend",
    "database"
)

foreach ($vm in $vms) {

    if ($status -match ",$vm,state,running") {
        Write-Host "[PASS] $vm VM is running"
    }
    else {
        Write-Host "[FAIL] $vm VM is not running"
        exit 1
    }
}

Write-Host ""
Write-Host "Checking application..."

try {
    $workouts = Invoke-RestMethod `
        -Uri "http://192.168.56.10/api/workouts" `
        -Method Get

    if ($workouts.Count -gt 0) {
        Write-Host "[PASS] Application returned stored workout data"
        Write-Host "Found $($workouts.Count) workout(s)"
    }
    else {
        Write-Host "[FAIL] Application returned no workout data"
        exit 1
    }
}
catch {
    Write-Host "[FAIL] Application request failed"
    Write-Host $_.Exception.Message
    exit 1
}

Write-Host ""
Write-Host "All verification checks passed."
$frontendUrl = terraform output -raw frontend_url

if (-not $frontendUrl) {
    Write-Host "FAIL: Could not get frontend URL from Terraform."
    exit 1
}

$baseUrl = "$frontendUrl/api"

Write-Host "Testing Gym Tracker at $baseUrl"

$testName = "CloudTest-" + (Get-Date -Format "yyyyMMddHHmmss")

$body = @{
    exercise_name = $testName
    sets          = 2
    reps          = 5
    weight        = 10
} | ConvertTo-Json

Write-Host "Adding test workout: $testName"

try {
    $createdWorkout = Invoke-RestMethod `
        -Uri "$baseUrl/workouts" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body
}
catch {
    Write-Host "FAIL: Could not add workout."
    Write-Host $_
    exit 1
}

Write-Host "Workout added."

try {
    $workouts = Invoke-RestMethod `
        -Uri "$baseUrl/workouts" `
        -Method Get
}
catch {
    Write-Host "FAIL: Could not retrieve workouts."
    Write-Host $_
    exit 1
}

$found = $workouts | Where-Object {
    $_.exercise_name -eq $testName
}

if (-not $found) {
    Write-Host "FAIL: Workout was not found after creation."
    exit 1
}

Write-Host "PASS: Workout was written and read back successfully."

Write-Host "Cleaning up test workout..."

try {
    Invoke-RestMethod `
        -Uri "$baseUrl/workouts/$($createdWorkout.id)" `
        -Method Delete | Out-Null

    Write-Host "Test workout removed."
}
catch {
    Write-Host "WARNING: Verification passed, but the test workout could not be removed."
    Write-Host $_
    exit 1
}

Write-Host ""
Write-Host "All verification checks passed."
exit 0
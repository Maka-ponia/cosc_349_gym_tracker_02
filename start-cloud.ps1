
$ErrorActionPreference = "Stop"

Write-Host "Starting Gym Tracker..."

$frontendId = terraform output -raw frontend_instance_id
$backendId = terraform output -raw backend_instance_id

if (-not $frontendId -or -not $backendId) {
    Write-Host "ERROR: Could not get frontend or backend instance ID from Terraform."
    exit 1
}

Write-Host "Starting backend..."
aws ec2 start-instances `
    --region us-east-1 `
    --instance-ids $backendId | Out-Null

Write-Host "Starting frontend..."
aws ec2 start-instances `
    --region us-east-1 `
    --instance-ids $frontendId | Out-Null

Write-Host "Waiting for EC2 instances..."

aws ec2 wait instance-running `
    --region us-east-1 `
    --instance-ids $backendId $frontendId

Write-Host "EC2 instances are running."

$frontendUrl = terraform output -raw frontend_url
$apiUrl = "$frontendUrl/api/"

Write-Host "Waiting for Gym Tracker API..."

$maxAttempts = 30
$attempt = 0
$ready = $false

while ($attempt -lt $maxAttempts) {

    try {
        $response = Invoke-RestMethod `
            -Uri $apiUrl `
            -Method Get `
            -TimeoutSec 5

        if ($response.message -eq "Gym Tracker API is running") {
            $ready = $true
            break
        }
    }
    catch {
    }

    $attempt++

    Write-Host "Application not ready yet. Retrying..."
    Start-Sleep -Seconds 5
}

if (-not $ready) {
    Write-Host ""
    Write-Host "ERROR: Gym Tracker did not become ready."
    Write-Host "Frontend: $frontendUrl"
    exit 1
}

Write-Host ""
Write-Host "Gym Tracker is ready."
Write-Host "Frontend: $frontendUrl"

Write-Host ""
Write-Host "Opening Gym Tracker in browser..."

Start-Process $frontendUrl

Write-Host ""
Write-Host "Run verification with:"
Write-Host ".\verify-cloud.ps1"
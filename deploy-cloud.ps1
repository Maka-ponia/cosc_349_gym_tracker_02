$ErrorActionPreference = "Stop"

Write-Host "=== Gym Tracker Cloud Deployment ==="
Write-Host ""

Write-Host "Checking AWS credentials..."

aws sts get-caller-identity | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: AWS credentials are not valid."
    Write-Host "Start the AWS Academy lab and update your AWS CLI credentials."
    exit 1
}

Write-Host "AWS credentials are valid."
Write-Host ""

Write-Host "Initialising Terraform..."

terraform init

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Terraform initialisation failed."
    exit 1
}

Write-Host ""
Write-Host "Validating Terraform configuration..."

terraform validate

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Terraform configuration is invalid."
    exit 1
}

Write-Host ""
Write-Host "Creating Terraform plan..."

terraform plan -out="gymtracker.tfplan"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Terraform plan failed."
    exit 1
}

Write-Host ""
Write-Host "Deploying Gym Tracker..."

terraform apply "gymtracker.tfplan"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Deployment failed."
    exit 1
}

Remove-Item "gymtracker.tfplan" -ErrorAction SilentlyContinue

$frontendUrl = terraform output -raw frontend_url

Write-Host ""
Write-Host "=== Deployment Complete ==="
Write-Host "Gym Tracker: $frontendUrl"
Write-Host ""

# Verify deployment
Write-Host "Running automated verification..."
Write-Host ""

# Wait for application to become ready
$frontendUrl = terraform output -raw frontend_url
$apiUrl = "$frontendUrl/api/"

Write-Host ""
Write-Host "Waiting for Gym Tracker to become ready..."

$maxAttempts = 60
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
        # Application is still starting
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

Write-Host ""
Write-Host "Running automated verification..."
Write-Host ""


.\verify-cloud.ps1
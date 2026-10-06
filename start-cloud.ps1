
$ErrorActionPreference = "Stop"

Write-Host "Starting Gym Tracker..."

$frontendId = aws ec2 describe-instances `
    --region us-east-1 `
    --filters "Name=tag:Name,Values=gymtracker-frontend" `
              "Name=instance-state-name,Values=stopped,running" `
    --query "Reservations[].Instances[].InstanceId" `
    --output text

$backendId = aws ec2 describe-instances `
    --region us-east-1 `
    --filters "Name=tag:Name,Values=gymtracker-backend" `
              "Name=instance-state-name,Values=stopped,running" `
    --query "Reservations[].Instances[].InstanceId" `
    --output text

if (-not $frontendId -or -not $backendId) {
    Write-Host "ERROR: Could not find frontend or backend EC2 instance."
    exit 1
}

Write-Host "Starting backend..."
aws ec2 start-instances --region us-east-1 --instance-ids $backendId | Out-Null

Write-Host "Starting frontend..."
aws ec2 start-instances --region us-east-1 --instance-ids $frontendId | Out-Null

Write-Host "Waiting for instances to start..."

aws ec2 wait instance-running `
    --region us-east-1 `
    --instance-ids $backendId $frontendId

Write-Host ""
Write-Host "Gym Tracker is running."
$frontendUrl = terraform output -raw frontend_url

Write-Host ""
Write-Host "Gym Tracker is running."
Write-Host "Frontend: $frontendUrl"
Write-Host ""
Write-Host "Run verification with:"
Write-Host ".\verify-cloud.ps1"
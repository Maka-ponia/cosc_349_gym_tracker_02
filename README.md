# Gym Workout Tracker

## Overview

The Gym Workout Tracker is a cloud-hosted web application that allows users to view, add, and edit workout records. It also calculates the workout volume for each workout using:

`sets × reps × weight`

The application is deployed on Amazon Web Services (AWS), with the infrastructure managed using Terraform.

## Architecture

The application consists of two Amazon EC2 instances, an Amazon RDS PostgreSQL database, and Amazon CloudWatch monitoring.

The main request flow is:

`Browser → Frontend EC2/Nginx → Backend EC2/Flask → Amazon RDS/PostgreSQL`

The backend also publishes a custom `WorkoutAdded` metric to Amazon CloudWatch whenever a new workout is successfully added.

### Frontend

The frontend runs on an Amazon EC2 instance using Nginx.

It:

- Serves the HTML and JavaScript user interface.
- Acts as a reverse proxy for API requests.
- Forwards `/api/` requests to the backend EC2 instance.
- Uses an Elastic IP to provide a stable public address while the deployment exists.

### Backend

The backend runs on a separate Amazon EC2 instance using Python and Flask.

It:

- Handles API requests.
- Reads and writes workout data.
- Calculates workout volume.
- Communicates with the RDS PostgreSQL database.
- Publishes the `WorkoutAdded` custom metric to Amazon CloudWatch.

Access to the Flask API is restricted by an AWS Security Group so that port 5000 accepts requests from the frontend Security Group.

### Database

Workout data is stored in an Amazon RDS PostgreSQL database.

The database:

- Stores workout records persistently.
- Is not publicly accessible.
- Accepts PostgreSQL connections from the backend Security Group.
- Automatically creates the `workouts` table when the backend starts if the table does not already exist.

### CloudWatch

Amazon CloudWatch provides monitoring for the application.

When a workout is successfully added, the backend publishes the custom metric:

`GymTracker / WorkoutAdded`

This provides a record of successful workout creation activity.

## Infrastructure as Code

The AWS infrastructure is defined in `main.tf` and managed using Terraform.

Terraform provisions:

- VPC
- Subnets
- Internet Gateway
- Route table and associations
- Security Groups
- Frontend EC2 instance
- Backend EC2 instance
- Amazon RDS PostgreSQL database
- Elastic IP
- Supporting networking resources

The EC2 instances are automatically configured using Terraform user data.

## Requirements

The deployment requires:

- AWS Academy Learner Lab access
- AWS CLI
- Terraform
- PowerShell

The application is deployed in the AWS `us-east-1` region.

Before running the deployment, start the AWS Academy Learner Lab and configure the AWS CLI using the temporary credentials supplied by the lab.

AWS credentials, Terraform state files, private keys, environment files, and Terraform variable files containing secrets must not be committed to the repository.

## Initial Deployment

The initial cloud deployment is automated using `deploy-cloud.ps1`.

Clone the repository and open PowerShell in the project directory.

Make sure the AWS Academy Learner Lab is running and the AWS CLI credentials are current.

The credentials can be checked with:

```powershell
aws sts get-caller-identity
```

Then deploy the application with:

```powershell
.\deploy-cloud.ps1
```

The deployment script:

1. Checks that the AWS credentials are valid.
2. Initialises Terraform.
3. Validates the Terraform configuration.
4. Creates a Terraform deployment plan.
5. Applies the plan to AWS.
6. Waits for the application to become available.
7. Runs the automated verification script.

A completely fresh deployment creates the required AWS infrastructure automatically without requiring manual configuration through the AWS Console.

The RDS database can take several minutes to provision during a fresh deployment.

## Accessing the Application

The frontend uses an Elastic IP so that its public address remains stable while the current deployment exists.

The current frontend URL can be retrieved with:

```powershell
terraform output -raw frontend_url
```

The application allows users to:

- View stored workouts
- Add new workouts
- Edit existing workouts
- View calculated workout volume

## Starting an Existing Deployment

If the infrastructure already exists but the frontend and backend EC2 instances have been stopped, run:

```powershell
.\start-cloud.ps1
```

The startup script:

1. Retrieves the frontend and backend EC2 instance IDs from Terraform.
2. Starts the EC2 instances.
3. Waits for AWS to report that the instances are running.
4. Waits for the Gym Tracker API to respond.
5. Opens the frontend automatically in the default web browser.

`start-cloud.ps1` starts an existing deployment. It does not create missing infrastructure or deploy application changes.

For infrastructure or application changes, use Terraform or rerun the deployment script.

## Verification

The application includes an automated end-to-end verification script:

```powershell
.\verify-cloud.ps1
```

The script:

1. Retrieves the frontend URL from Terraform.
2. Creates a uniquely named `CloudTest` workout.
3. Sends the workout through the frontend `/api` reverse proxy.
4. Causes the backend to write the workout to Amazon RDS.
5. Retrieves the workout data through the API.
6. Confirms that the newly created workout can be read back.
7. Removes the test workout after successful verification.

A successful test reports:

```text
PASS: Workout was written and read back successfully.
Test workout removed.

All verification checks passed.
```

Creating the test workout also causes the backend to publish the `WorkoutAdded` custom metric to Amazon CloudWatch.

This test verifies an important workflow across the frontend, backend, database, and monitoring components.

## Security

AWS Security Groups restrict communication between the application components.

The main permitted paths are:

`Internet → Frontend: HTTP port 80`

`Frontend → Backend: Flask port 5000`

`Backend → RDS: PostgreSQL port 5432`

The RDS database is configured as non-publicly accessible.

The backend uses the AWS Academy `LabInstanceProfile` to obtain the AWS permissions required to publish CloudWatch metrics without storing AWS credentials on the EC2 instance.

## Stopping the Application

The frontend and backend EC2 instances can be stopped when the application is not required.

They can later be restarted with:

```powershell
.\start-cloud.ps1
```

Stopping the EC2 instances does not remove the Terraform-managed infrastructure or destroy the RDS database.

## Removing the Deployment

Terraform can preview the resources that will be removed with:

```powershell
terraform plan -destroy
```

To completely remove the deployment:

```powershell
terraform destroy
```

Review the proposed destruction and enter `yes` when prompted.

This removes the AWS resources managed by Terraform. The RDS database and its stored workout data are also deleted because the current assignment configuration does not create a final database snapshot.

After destruction, the complete infrastructure can be recreated using:

```powershell
.\deploy-cloud.ps1
```

A new Elastic IP may be allocated after a complete destroy and redeployment. The scripts retrieve the current address from Terraform rather than relying on a hard-coded IP address.

## Repository Structure

```text
.
├── backend/
│   └── app.py
├── frontend/
│   └── index.html
├── main.tf
├── README.md
├── deploy-cloud.ps1
├── start-cloud.ps1
└── verify-cloud.ps1
```

Terraform working directories, state files, credentials, local variable files, and saved Terraform plans are excluded from the repository using `.gitignore`.
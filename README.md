# Gym Workout Tracker

## Overview

The Gym Workout Tracker is a simple web application that allows users to view, add, and edit workout records.

The application is deployed across three virtual machines using Vagrant and VirtualBox. Each user request passes through the frontend VM, backend VM, and database VM.

## Architecture

### Frontend VM

* IP address: `192.168.56.10`
* Software: Nginx
* Serves the HTML and JavaScript user interface.
* Acts as a reverse proxy for API requests.
* Requests to `/api/` are forwarded to the backend VM.

### Backend VM

* IP address: `192.168.56.11`
* Software: Python and Flask
* Handles API requests.
* Performs application logic such as workout volume calculation.
* Communicates with the PostgreSQL database.

### Database VM

* IP address: `192.168.56.12`
* Software: PostgreSQL
* Stores workout records.
* Contains preloaded demonstration workout data after a clean deployment.

The request flow is:

`Browser → Frontend/Nginx → Backend/Flask → Database/PostgreSQL`

## Requirements

The system has been tested with:

* Windows 11
* Vagrant `2.4.9`
* VirtualBox `7.2.16r174877`
* Ubuntu Jammy 22.04 Vagrant box (`ubuntu/jammy64`)

Vagrant and VirtualBox must be installed before deploying the application.

## Deployment

Clone the repository and open PowerShell in the project directory.

Run:

```powershell
vagrant up
```

This command creates and provisions all three virtual machines.

The provisioning process automatically installs and configures:

* Nginx on the frontend VM
* Python and Flask on the backend VM
* PostgreSQL on the database VM
* Demo workout data in the PostgreSQL database
* The backend systemd service

No additional manual configuration should be required.

## Accessing the Application

Once deployment is complete, open a web browser and visit:

`http://192.168.56.10`

The application allows users to:

* View stored workouts
* Add new workouts
* Edit existing workouts
* View calculated workout volume

Workout volume is calculated as:

`sets × reps × weight`

## Verification

An automated PowerShell verification script is included.

Run:

```powershell
.\verify.ps1
```

The script checks that:

* The frontend VM is running
* The backend VM is running
* The database VM is running
* The application can complete an API request that retrieves stored workout data

A successful verification should finish with:

```text
All verification checks passed.
```

## Stopping the Application

To shut down the virtual machines without deleting them, run:

```powershell
vagrant halt
```

The existing virtual machines and database contents will remain available for the next startup.

## Removing the Deployment

To completely remove all virtual machines, run:

```powershell
vagrant destroy -f
```

The project source files remain on the host computer, but the virtual machines and data stored inside them are deleted.

A fresh deployment can then be recreated using:

```powershell
vagrant up
```

## Troubleshooting

If Vagrant remains at `Waiting for machine to boot` for an unusually long period on Windows, restart the host machine and retry the deployment.

The normal deployment procedure is still:

```powershell
vagrant up
```

and should not require manual VM configuration.

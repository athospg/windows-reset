# Post install script for Windows after a reset

Script to install and configure the PC after a Windows reset.

## Prerequisites

The script requires that the execution policy allows running scripts. You can set it to RemoteSigned for the current user by running the following command in PowerShell as Administrator:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Usage

The script requires administrative privileges to run. You can execute it by opening PowerShell as Administrator and running the following command:

```powershell
.\setup-pc.ps1
```

To select the default options for frontend development, you can run the script with the `-front` parameter:

```powershell
.\setup-pc.ps1 -front
```

To select the default options for backend development, you can run the script with the `-back` parameter:

```powershell
.\setup-pc.ps1 -back
```

To select both frontend and backend development options, you can run the script with both parameters:

```powershell
.\setup-pc.ps1 -front -back
```

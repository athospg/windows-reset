# Post install script for Windows after a reset

Script to install and configure the PC after a Windows reset.

## Prerequisites

The script requires that the execution policy allows running scripts. You can set it to RemoteSigned for the current user by running the following command in PowerShell (no administrator needed for the CurrentUser scope):

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Usage

The script needs administrative privileges, but you don't have to open an elevated terminal to run it: when started without elevation, the script automatically relaunches itself with administrator rights (accept the UAC prompt). Just run the following command from any PowerShell window:

```powershell
.\setup-win.ps1
```

To select the default options for frontend development, you can run the script with the `-front` parameter:

```powershell
.\setup-win.ps1 -front
```

To select the default options for backend development, you can run the script with the `-back` parameter:

```powershell
.\setup-win.ps1 -back
```

To select both frontend and backend development options, you can run the script with both parameters:

```powershell
.\setup-win.ps1 -front -back
```

Skip flags are also available for partial runs:

```powershell
.\setup-win.ps1 -NoApps    # skips the apps menu (menu 1)
.\setup-win.ps1 -NoTweaks  # skips the tweaks menu (menu 2)
.\setup-win.ps1 -NoPwsh    # skips the PowerShell profile menu (3)
.\setup-win.ps1 -NoApps -NoTweaks  # only reconfigure the PowerShell profile
```

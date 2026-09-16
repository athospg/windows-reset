# Post install script for Windows after a reset

Script to install and configure the PC after a Windows reset.

## Prerequisites

The script requires that the execution policy allows running scripts. You can set it to RemoteSigned for the current user by running the following command in PowerShell (no administrator needed for the CurrentUser scope):

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Usage

The script works in any PowerShell window. When an admin account is available, the script automatically relaunches itself elevated (accept the UAC prompt). Running from a standard user also works: elevation-only items (machine-wide installs such as the Visual C++/.NET runtimes, PowerShell 7, DBeaver, Go, Nerd Fonts and the VS Code context menu) show up disabled (with a [*] marker) and everything else runs normally - PowerShell modules install with `-Scope CurrentUser` in that case:

```powershell
.\setup-win.ps1
```

Packages whose winget manifest supports a per-user install (Git, Edge WebView2, JetBrains Toolbox) are installed with `--scope user`, so they also work for standard users.

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

## Testing

Four ways to validate the script, from cheapest to most realistic:

**1. Offline logic tests** (no Windows needed, works on Linux/WSL):

```powershell
pwsh -NoProfile -File tests/run-tests.ps1
```

Covers the catalog invariants, the `--scope user` argument building, the elevation decision and the profile merge.

**2. Dry run** - runs the menus and the confirmation, then prints every action that would run without installing, writing or rebooting (no UAC prompt):

```powershell
.\setup-win.ps1 -DryRun
.\setup-win.ps1 -front -DryRun
```

**3. Package preflight** - checks that every package ID in the catalog still resolves in winget, and optionally that the per-user (`--scope user`) packages really support that scope. Nothing is installed; downloads are discarded:

```powershell
pwsh -NoProfile -File tools/Test-CatalogPackages.ps1
pwsh -NoProfile -File tools/Test-CatalogPackages.ps1 -CheckScope
```

**4. Disposable end-to-end run** - Windows Sandbox (Pro/Enterprise/Edu): the repository is mapped read-only and everything installs inside a throwaway environment:

```powershell
pwsh -NoProfile -File sandbox/Start-Sandbox.ps1
pwsh -NoProfile -File sandbox/Start-Sandbox.ps1 -SetupArgs "-front"
```

Do not select WSL2 inside the sandbox (no nested virtualization) and expect the final reboot to be unavailable there.

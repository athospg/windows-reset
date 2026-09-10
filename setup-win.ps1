<#
.SYNOPSIS
    Automation script for initial setup of the development environment on Windows.

.DESCRIPTION
    Installs CLI utilities, development tools, IDEs, browsers, and enables
    WSL2 with Ubuntu via interactive terminal menus. Three menus drive the
    flow: apps installation, system tweaks, and PowerShell profile blocks.
    Helper code lives in the 'invoke/' folder and is dot-sourced below.
    The script self-elevates when an admin account is available; running
    from a standard user works too, with elevation-only items (machine-wide
    installs, Nerd Fonts, VS Code context menu) disabled in the menus.

.PARAMETER front
    Pre-selects recommended software for Frontend development.

.PARAMETER back
    Pre-selects recommended software for Backend development.

.PARAMETER NoPwsh
    Skips the PowerShell profile configuration menu; no $PROFILE is written.

.PARAMETER NoApps
    Skips the apps selection menu; no app installations run.

.PARAMETER NoTweaks
    Skips the tweaks selection menu; no tweaks are applied.

.PARAMETER help
    Displays this help menu with instructions for using the script.

.EXAMPLE
    .\setup-win.ps1 -front
    .\setup-win.ps1 -back
    .\setup-win.ps1 -front -back
    .\setup-win.ps1 -NoApps -NoTweaks   # only reconfigure the profile
#>

param (
    [switch]$front,
    [switch]$back,
    # Skip the PowerShell profile menu and never write to any $PROFILE
    [switch]$NoPwsh,
    # Skip the apps selection menu (menu 1): no app installations run
    [switch]$NoApps,
    # Skip the tweaks selection menu (menu 2): no tweaks are applied
    [switch]$NoTweaks,
    # Internal: username captured before the self-elevation relaunch. Used to
    # abort when UAC elevates with a different admin account, which would make
    # every per-user install ($LOCALAPPDATA, $PROFILE, npm, fnm) land on the
    # wrong user profile.
    [string]$ElevatedFor = "",
    [Alias("h", "?", "-help")]
    [switch]$help
)

if ($help) {
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit
}

# 1. Elevation strategy
# - Already elevated: run as-is (the -ElevatedFor guard below only applies
#   when this process was spawned by the self-elevation relaunch).
# - Running as an admin-group user: relaunch elevated (same user guaranteed).
# - Standard user: DON'T elevate. The menus stay available with the
#   elevation-only items disabled (fonts, machine-wide installs, HKCR
#   tweaks...) and PowerShell modules install with -Scope CurrentUser.
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    # Relaunch keeps the window open (-NoExit) so errors don't vanish instantly.
    # Only pass flags when true: PowerShell 5.1's -File mode cannot convert
    # the string "False" into a [switch] parameter bound with ":$false".
    $relaunchArgs = "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $relaunchArgs += " -ElevatedFor `"$env:USERNAME`""
    if ($front) { $relaunchArgs += " -front" }
    if ($back) { $relaunchArgs += " -back" }
    if ($NoPwsh) { $relaunchArgs += " -NoPwsh" }
    if ($NoApps) { $relaunchArgs += " -NoApps" }
    if ($NoTweaks) { $relaunchArgs += " -NoTweaks" }

    Start-Process powershell $relaunchArgs -Verb RunAs
    exit
} else {
    Write-Host "Running WITHOUT elevation: items that require administrator rights" -ForegroundColor Yellow
    Write-Host "are disabled in the menus (marked [*] with [✗]); everything else works normally." -ForegroundColor Yellow
}

# Guard: the elevated session (spawned by the self-elevation relaunch above)
# must belong to the same user that launched the script. Per-user installs
# ($LOCALAPPDATA, $PROFILE, npm/fnm globals) would otherwise land on another
# account's profile. Running already elevated without a relaunch skips this
# check (-ElevatedFor empty).
if ($ElevatedFor -and $env:USERNAME -ne $ElevatedFor) {
    Write-Host @"

ERROR: the elevated session is running as '$env:USERNAME', but the script
was launched from '$ElevatedFor'. Per-user installations (VS Code, fnm, npm,
profiles in Documents, etc.) would be placed on the wrong user profile.

Re-run the script from your own admin account so the UAC prompt uses the
credentials of '$ElevatedFor'.
"@ -ForegroundColor Red
    exit 1
}

# Base path shared with every helper module
$PSScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Dot-source the helper modules (shared session scope keeps the small
# helpers decoupled from the orchestration below)
. (Join-Path $PSScriptDir "invoke\ui.ps1")        # Show-TerminalMenu
. (Join-Path $PSScriptDir "invoke\detect.ps1")    # Test-WingetInstalled, Get-InstalledAvailability
. (Join-Path $PSScriptDir "invoke\catalog.ps1")   # Get-AppCatalog, New-TweakCatalog
. (Join-Path $PSScriptDir "invoke\fonts.ps1")     # Install-NerdFont
. (Join-Path $PSScriptDir "invoke\profile.ps1")   # Get-ProfileBlock, Merge-ProfileBlock, Update-PowerShellProfiles

$vscodeMenuScript = Join-Path $PSScriptDir "vscode-context-menu.ps1"

# ------------------------------------------------------------------------------
# MENU 1: APPS
# ------------------------------------------------------------------------------
$catalogo = Get-AppCatalog

# Without elevation, disable every item in the catalogs that requires admin
if (-not $isAdmin) {
    foreach ($item in $catalogo) {
        $item | Add-Member -NotePropertyName Disabled -NotePropertyValue $item.NeedsAdmin -Force
    }
}

# Pre-selection flags
for ($i = 0; $i -lt $catalogo.Count; $i++) {
    $item = $catalogo[$i]
    $item.Marcado = (
        ($front -and $back -and ($item.Front -or $item.Back)) -or
        ($front -and -not $back -and $item.Front) -or
        ($back -and -not $front -and $item.Back)
    )
}

if ($NoApps) {
    Write-Host "Skipping app installations (-NoApps)." -ForegroundColor Yellow
    $selecionados = @()
} else {
    $appMarcados = Show-TerminalMenu -Items $catalogo -Title "INSTALLATION PACKAGE SELECTION"
    $selecionados = @($appMarcados | ForEach-Object { $catalogo[$_] })
}

# ------------------------------------------------------------------------------
# MENU 2: SYSTEM TWEAKS
# Pre-marks take into account what is already installed on the system
# (winget list + Get-Command fallback) and what the user just selected to install.
# ------------------------------------------------------------------------------
$availability = Get-InstalledAvailability -Selecionados $selecionados -SkipWingetScan:$NoTweaks
$fnmAvailable = $availability.Fnm
$nvmAvailable = $availability.Nvm
$fzfAvailable = $availability.Fzf
$ompAvailable = $availability.Omp

$tweaks = New-TweakCatalog -NodeManagerAvailable $availability.NodeManager -FzfAvailable $availability.Fzf -VscodeAvailable $availability.Vscode

# Without elevation, disable the tweaks that require admin (fonts write to
# HKLM; the VS Code context menu tweak writes to HKCR)
if (-not $isAdmin) {
    foreach ($item in $tweaks) {
        $item | Add-Member -NotePropertyName Disabled -NotePropertyValue $item.NeedsAdmin -Force
    }
}

if ($NoTweaks) {
    Write-Host "Skipping system tweaks (-NoTweaks)." -ForegroundColor Yellow
    $tweaksSelecionados = @()
} else {
    $tweakMarcados = Show-TerminalMenu -Items $tweaks -Title "SYSTEM TWEAKS SELECTION"
    $tweaksSelecionados = @($tweakMarcados | ForEach-Object { $tweaks[$_] })
}

# pnpm requires the Node.js LTS tweak to be selected
if ($tweaksSelecionados.ID -contains "Tweak.pnpm" -and -not ($tweaksSelecionados.ID -contains "Tweak.NodeLTS")) {
    $tweaksSelecionados = @($tweaksSelecionados | Where-Object { $_.ID -ne "Tweak.pnpm" })
    Write-Host "`nNOTE: pnpm was skipped because Node.js LTS was not selected." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
}

# OpenCode requires Node.js/npm (installed via the Node.js LTS tweak)
if ($tweaksSelecionados.ID -contains "Tweak.OpenCode" -and -not ($tweaksSelecionados.ID -contains "Tweak.NodeLTS") -and -not ($fnmAvailable -and [bool](Get-Command npm -ErrorAction SilentlyContinue))) {
    $tweaksSelecionados = @($tweaksSelecionados | Where-Object { $_.ID -ne "Tweak.OpenCode" })
    Write-Host "`nNOTE: OpenCode was skipped because Node.js/npm was not selected or found." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
}

# Warn about PSFzf module without the fzf binary
if ($tweaksSelecionados.ID -contains "Module.PSFzf" -and -not $fzfAvailable) {
    Write-Host "`nNOTE: PSFzf selected, but the fzf binary was not found. PSFzf key bindings will warn at runtime." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
}

# The execution continues even with nothing selected in menus 1/2: the
# PowerShell profile menu (3) can still be used (unless -NoPwsh is passed)

# ------------------------------------------------------------------------------
# MENU 3: POWERSHELL PROFILE SELECTION
# The actual profile writing happens later, during execution, so the
# confirmation screen can list everything (apps + tweaks + profile blocks).
# ------------------------------------------------------------------------------
# Modules selected in the tweaks menu drive the profile block premarks
$selectedModules = @($tweaksSelecionados | Where-Object { $_.ID -like "Module.*" } | ForEach-Object { $_.Modulo })

# Chosen profile block ids (populated by the menu below; empty with -NoPwsh)
$chosenBlockIds = @()

$profileBlocks = @(
    [PSCustomObject]@{ Id = "omp";            Nome = "Oh My Posh theme + omp function";    Categoria = "Prompt";  Marcado = $ompAvailable }
    [PSCustomObject]@{ Id = "fnm";            Nome = "FNM initialization";                 Categoria = "Runtime"; Marcado = ($tweaksSelecionados.ID -contains "Tweak.NodeLTS") }
    [PSCustomObject]@{ Id = "psreadline";     Nome = "PSReadLine import + options";        Categoria = "Module";  Marcado = ($selectedModules -contains "PSReadLine") }
    [PSCustomObject]@{ Id = "terminal-icons"; Nome = "Terminal-Icons import";              Categoria = "Module";  Marcado = ($selectedModules -contains "Terminal-Icons") }
    [PSCustomObject]@{ Id = "psfzf";          Nome = "PSFzf import + key bindings";        Categoria = "Module";  Marcado = ($selectedModules -contains "PSFzf") }
    [PSCustomObject]@{ Id = "az";             Nome = "Azure CLI argument completer";       Categoria = "CLI";     Marcado = ([bool](Get-Command az -ErrorAction SilentlyContinue)) }
)

if (-not $NoPwsh) {
    $profileBlockIndices = Show-TerminalMenu -Items $profileBlocks -Title "POWERSHELL PROFILE CONFIGURATION"
    $chosenBlockIds = @($profileBlockIndices | ForEach-Object { $profileBlocks[$_].Id })
} else {
    Write-Host "Skipping PowerShell profile configuration (-NoPwsh)." -ForegroundColor Yellow
}

# ------------------------------------------------------------------------------
# CONFIRMATION
# Runs after ALL menus so the summary covers everything that will be
# processed: apps, system tweaks and profile blocks.
# ------------------------------------------------------------------------------
$precisaWSL = $selecionados.ID -contains "WSL2"

Clear-Host
Write-Host "==================================================================" -ForegroundColor Red
Write-Host " The following will be processed:" -ForegroundColor Yellow
if ($selecionados.Count -gt 0) {
    $selecionados | ForEach-Object { Write-Host "  - [$($_.Categoria)] $($_.Nome)" -ForegroundColor Cyan }
}
if ($tweaksSelecionados.Count -gt 0) {
    Write-Host "  System tweaks:" -ForegroundColor Yellow
    $tweaksSelecionados | ForEach-Object { Write-Host "  - [$($_.Categoria)] $($_.Nome)" -ForegroundColor Cyan }
}
if (-not $NoPwsh) {
    $chosenBlocksItems = @($profileBlocks | Where-Object { $chosenBlockIds -contains $_.Id })
    if ($chosenBlocksItems.Count -gt 0) {
        Write-Host "  PowerShell profile:" -ForegroundColor Yellow
        $chosenBlocksItems | ForEach-Object { Write-Host "  - [$($_.Categoria)] $($_.Nome)" -ForegroundColor Cyan }
    } else {
        Write-Host "  PowerShell profile: nothing selected (profile untouched)." -ForegroundColor Gray
    }
}
if ($selecionados.Count -eq 0 -and $tweaksSelecionados.Count -eq 0 -and $chosenBlockIds.Count -eq 0) {
    if ($NoPwsh) {
        Write-Host "  Nothing to process." -ForegroundColor Gray
    } else {
        Write-Host "  No changes selected." -ForegroundColor Gray
    }
}

if ($precisaWSL) {
    Write-Host "`n NOTE: WSL2 is selected. THE SYSTEM WILL REBOOT AT THE END." -ForegroundColor Red
}

Write-Host "==================================================================" -ForegroundColor Red
Write-Host "`nPress any key to START or 'Ctrl + C' to cancel..." -ForegroundColor Green
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# ==============================================================================
# EXECUTION
# ==============================================================================
Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "   Starting Dev Environment Configuration        " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# APP INSTALLATION
# ------------------------------------------------------------------------------
# Default arguments for winget to ensure silent installation and acceptance of agreements
$wingetArgs = @("--silent", "--accept-package-agreements", "--accept-source-agreements", "--ignore-security-hash")

# VS Code installs silently. The context menu entries are created by
# the 'vscode-context-menu.ps1' tweak step, so the equivalent installer
# tasks are disabled here to avoid duplicated entries.
# Task names are the same for stable and Insiders builds (build/win32/code.iss).
$vscodeArgs = @("--silent", "--accept-package-agreements", "--accept-source-agreements",
    "--override", '/VERYSILENT /NORESTART /MERGETASKS="!runcode,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath"')

winget settings --enable InstallerHashOverride

# Update Winget sources to ensure latest packages are available
if ($selecionados.Count -gt 0) {
    winget source update
}

foreach ($item in $selecionados) {
    Write-Host "`nInstalling: $($item.Nome)..." -ForegroundColor Yellow

    switch ($item.ID) {
        "Microsoft.VisualStudioCode" {
            winget install --id $item.ID $vscodeArgs
        }
        "Microsoft.VisualStudioCode.Insiders" {
            winget install --id $item.ID $vscodeArgs
        }
        "CoreyButler.NVMforWindows" {
            # Install directly from the official GitHub releases: the winget
            # community manifest lags behind (currently 1.2.2 while the project
            # is already on v2.x under nvm-windows/nvm). The v2 setup is built
            # with Inno Setup, so /VERYSILENT works.
            $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/nvm-windows/nvm/releases?per_page=20" -UseBasicParsing

            # Latest stable release (pre-releases are skipped)
            $stableRelease = @($releases | Where-Object { -not $_.prerelease })[0]
            $setupAsset = $stableRelease.assets | Where-Object { $_.name -like "*-amd64-setup.exe" } | Select-Object -First 1

            if ($null -eq $setupAsset) {
                Write-Host "WARNING: no amd64 setup asset found in the latest NVM release." -ForegroundColor Yellow
                continue
            }

            Write-Host "Downloading $($setupAsset.name) ($($stableRelease.tag_name))..." -ForegroundColor Cyan
            $setupPath = Join-Path $env:TEMP $setupAsset.name
            Invoke-WebRequest -Uri $setupAsset.browser_download_url -OutFile $setupPath -UseBasicParsing

            Start-Process -FilePath $setupPath -ArgumentList "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART" -Wait
            Remove-Item $setupPath -Force -ErrorAction SilentlyContinue

            Write-Host "NVM for Windows installed successfully!" -ForegroundColor Green
        }
        "WSL2" {
            # Installs the WSL features and Ubuntu in a single step.
            # The distro finishes its setup on first boot after the reboot.
            wsl --install -d Ubuntu
        }
        Default {
            winget install --id $item.ID $wingetArgs
        }
    }
}

# Refresh PATH after app installs so newly installed tools are reachable
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# ------------------------------------------------------------------------------
# TWEAKS APPLICATION
# ------------------------------------------------------------------------------

# 1. Fonts
foreach ($tweak in ($tweaksSelecionados | Where-Object { $_.ID -like "Font.*" })) {
    Write-Host "`nInstalling font: $($tweak.Variant)..." -ForegroundColor Yellow
    Install-NerdFont -Variant $tweak.Variant -Url $tweak.Url
}

# 2. Node.js LTS via fnm or nvm-windows (whichever manager is available)
if ($tweaksSelecionados.ID -contains "Tweak.NodeLTS") {
    $fnmCmd = Get-Command fnm -ErrorAction SilentlyContinue
    $nvmCmd = Get-Command nvm -ErrorAction SilentlyContinue

    if ($fnmCmd) {
        Write-Host "`nConfiguring fnm and installing Node.js LTS..." -ForegroundColor Cyan

        # Refresh PATH so the newly installed fnm.exe is reachable in this session
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        # Install and set LTS version as default
        fnm install --lts
        fnm use lts-latest
        fnm default lts-latest

        # Build the fnm "multishell" PATH AFTER the version is installed, so
        # npm/npx/corepack become reachable in this session. Doing this AFTER
        # the install is essential: an env created before the install points
        # to no node version. Refreshing PATH from the registry afterwards
        # would erase the multishell entry again.
        fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression

        Write-Host "Node.js LTS installed successfully!" -ForegroundColor Green
    } elseif ($nvmCmd) {
        Write-Host "`nConfiguring nvm-windows and installing Node.js LTS..." -ForegroundColor Cyan

        # Refresh PATH so the newly installed nvm.exe is reachable in this session
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        # Install LTS and switch the symlink to it. nvm-windows requires an
        # elevated shell to create/update the NVM_SYMLINK junction - the setup
        # script already runs elevated, so 'nvm use' works here.
        nvm install lts
        nvm use lts

        Write-Host "Node.js LTS installed successfully!" -ForegroundColor Green
    } else {
        Write-Host "WARNING: Neither fnm nor nvm found. Node.js must be installed manually." -ForegroundColor Yellow
    }
}
# Remember which Node manager was used for the OpenCode step below
$fnmCmd = if ($tweaksSelecionados.ID -contains "Tweak.NodeLTS") { Get-Command fnm -ErrorAction SilentlyContinue } else { $null }

# 3. pnpm via Corepack (only meaningful after Node.js was installed)
if ($tweaksSelecionados.ID -contains "Tweak.pnpm") {
    if (Get-Command corepack -ErrorAction SilentlyContinue) {
        Write-Host "Enabling and activating pnpm via Corepack..." -ForegroundColor Cyan
        corepack enable
        corepack prepare pnpm@latest --activate
        Write-Host "pnpm activated successfully!" -ForegroundColor Green
    } else {
        Write-Host "WARNING: Corepack not found. Please install pnpm manually later." -ForegroundColor Yellow
    }
}

# 3.5 OpenCode AI agent via npm (requires Node.js installed by the tweak above)
if ($tweaksSelecionados.ID -contains "Tweak.OpenCode") {
    # Re-init the fnm environment so npm stays reachable even if the tweak
    # above ran earlier (its multishell PATH entry may have been rebuilt).
    if ($fnmCmd) {
        fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
    } else {
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    }

    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-Host "Installing OpenCode AI agent (npm install -g opencode-ai@latest)..." -ForegroundColor Cyan
        npm install -g opencode-ai@latest
        Write-Host "OpenCode installed successfully! Run it with 'opencode'." -ForegroundColor Green
    } else {
        Write-Host "WARNING: npm not found in PATH. Install OpenCode manually with: npm install -g opencode-ai@latest" -ForegroundColor Yellow
    }
}

# 4. PowerShell modules (installed into both hosts when PowerShell 7 exists).
# $selectedModules was already computed during the menu selection phase.
if ($selectedModules.Count -gt 0) {
    # 4.1 Force TLS 1.2 protocol and strong cryptography for .NET
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value 1 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value 1 -Type DWord -ErrorAction SilentlyContinue

    # 4.2 Bootstrap NuGet Provider directly (Bypasses interactive prompt entirely)
    $nugetProviderDir = "$env:ProgramFiles\PackageManagement\ProviderAssemblies\NuGet\2.8.5.208"
    if (-not (Test-Path $nugetProviderDir)) {
        Write-Host "Bootstrapping NuGet Package Provider..." -ForegroundColor Cyan
        New-Item -ItemType Directory -Path $nugetProviderDir -Force | Out-Null
        $nugetDllUrl = "https://onegetcdn.azureedge.net/providers/Microsoft.PackageManagement.NuGetProvider-2.8.5.208.dll"
        Invoke-WebRequest -Uri $nugetDllUrl -OutFile "$nugetProviderDir\Microsoft.PackageManagement.NuGetProvider.dll" -UseBasicParsing
    }

    # 4.3 Import provider and suppress confirmation warnings
    Import-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue

    # 4.4 Install PowerShell Modules silently (current user scope - no elevation needed)
    foreach ($mod in $selectedModules) {
        Write-Host "Installing module: $mod..." -ForegroundColor Cyan
        Install-Module -Name $mod -Force -SkipPublisherCheck -AllowClobber -Scope CurrentUser -Confirm:$false
    }

    # 4.5 Install the same modules into PowerShell 7's module directory
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        foreach ($mod in $selectedModules) {
            Write-Host "Installing module for PowerShell 7: $mod..." -ForegroundColor Cyan
            pwsh -NoProfile -Command "Install-Module -Name $mod -Force -SkipPublisherCheck -AllowClobber -Scope CurrentUser -Confirm:`$false"
        }
    }
}

# 5. Profile merge/write (the selection happened in menu 3; -NoPwsh never writes)
if (-not $NoPwsh) {
    Update-PowerShellProfiles -ChosenBlockIds $chosenBlockIds -ProfileBlocks $profileBlocks -ScriptDir $PSScriptDir
}

# 6. VS Code context menu entries (classic verbs for files/folders/background)
if ($tweaksSelecionados.ID -contains "Tweak.VSCodeMenu") {
    if (Test-Path $vscodeMenuScript) {
        Write-Host "Configuring VS Code context menu..." -ForegroundColor Cyan
        & $vscodeMenuScript
    } else {
        Write-Host "WARNING: 'vscode-context-menu.ps1' not found in '$PSScriptDir'." -ForegroundColor Yellow
    }
}

# ------------------------------------------------------------------------------
# COMPLETION AND REBOOT (IF WSL IS SET)
# ------------------------------------------------------------------------------
Write-Host "`n==================================================" -ForegroundColor Green
Write-Host " Setup completed successfully!" -ForegroundColor Green

if ($precisaWSL) {
    Write-Host " WSL requires a restart. System will restart in 15 seconds." -ForegroundColor Red
    Write-Host "==================================================" -ForegroundColor Green
    Start-Sleep -Seconds 15
    Restart-Computer -Force
} else {
    Write-Host " No pending installations require a restart." -ForegroundColor Green
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host "`nPress any key to exit..." -ForegroundColor Green
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

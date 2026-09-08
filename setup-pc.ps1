<#
.SYNOPSIS
    Automation script for initial setup of the development environment on Windows.

.DESCRIPTION
    Installs CLI utilities, development tools, IDEs, browsers,
    PowerShell modules, and enables WSL2 with Ubuntu via an interactive terminal menu.

.PARAMETER front
    Pre-selects recommended software for Frontend development.

.PARAMETER back
    Pre-selects recommended software for Backend development.

.PARAMETER help
    Displays this help menu with instructions for using the script.

.EXAMPLE
    .\setup-pc.ps1 -front
    .\setup-pc.ps1 -back
    .\setup-pc.ps1 -front -back
#>

param (
    [switch]$front,
    [switch]$back,
    [Alias("h", "?", "-help")]
    [switch]$help
)

if ($help) {
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit
}

# 1. Ensure Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -front:$front -back:$back" -Verb RunAs
    exit
}

$PSScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ------------------------------------------------------------------------------
# SOFTWARE CATALOG
# ------------------------------------------------------------------------------
$catalogo = @(
    [PSCustomObject]@{ ID = "Microsoft.PowerShell";              Nome = "PowerShell 7";                  Categoria = "CLI";       Front = $true;  Back = $true  }
    [PSCustomObject]@{ ID = "Microsoft.WindowsTerminal.Preview"; Nome = "Windows Terminal Preview";      Categoria = "CLI";       Front = $true;  Back = $true  }
    [PSCustomObject]@{ ID = "Microsoft.WindowsTerminal";         Nome = "Windows Terminal";              Categoria = "CLI";       Front = $false; Back = $false }
    [PSCustomObject]@{ ID = "JanDeDobbeleer.OhMyPosh";           Nome = "Oh My Posh";                    Categoria = "CLI";       Front = $true;  Back = $true  }
    [PSCustomObject]@{ ID = "junegunn.fzf";                      Nome = "fzf (Fuzzy Finder)";            Categoria = "CLI";       Front = $true;  Back = $true  }
    [PSCustomObject]@{ ID = "PSModules";                         Nome = "PowerShell Modules & Profile";  Categoria = "CLI";       Front = $true;  Back = $true  }
    [PSCustomObject]@{ ID = "Git.Git";                           Nome = "Git";                           Categoria = "Dev";       Front = $true;  Back = $true  }
    [PSCustomObject]@{ ID = "Fork.Fork";                         Nome = "Fork (Git Client)";             Categoria = "Dev";       Front = $true;  Back = $true  }
    [PSCustomObject]@{ ID = "Schniz.fnm";                        Nome = "fnm (Fast Node Manager)";       Categoria = "Dev";       Front = $true;  Back = $true  }
    [PSCustomObject]@{ ID = "Microsoft.VisualStudioCode.Insiders"; Nome = "VS Code Insiders";            Categoria = "Dev";       Front = $true;  Back = $true  }
    [PSCustomObject]@{ ID = "Microsoft.VisualStudioCode";        Nome = "VS Code";                       Categoria = "Dev";       Front = $false; Back = $false }
    [PSCustomObject]@{ ID = "SUSE.RancherDesktop";               Nome = "Rancher Desktop";               Categoria = "Dev";       Front = $false; Back = $true  }
    [PSCustomObject]@{ ID = "dbeaver.dbeaver";                   Nome = "DBeaver Community";             Categoria = "Dev";       Front = $false; Back = $true  }
    [PSCustomObject]@{ ID = "Microsoft.DotNet.SDK.10";           Nome = ".NET SDK 10";                   Categoria = "Dev";       Front = $false; Back = $true  }
    [PSCustomObject]@{ ID = "Brave.Brave";                       Nome = "Brave Browser";                 Categoria = "Browser";   Front = $true;  Back = $true  }
    [PSCustomObject]@{ ID = "WSL2";                              Nome = "WSL2 + Ubuntu";                 Categoria = "System";    Front = $false; Back = $false }
)

# ------------------------------------------------------------------------------
# FILTERING AND PRE-SELECTION FLAGS
# ------------------------------------------------------------------------------
$marcados = [System.Collections.Generic.HashSet[int]]::new()

for ($i = 0; $i -lt $catalogo.Count; $i++) {
    $item = $catalogo[$i]
    if (($front -and $back -and ($item.Front -or $item.Back)) -or
        ($front -and -not $back -and $item.Front) -or
        ($back -and -not $front -and $item.Back) -or
        (-not $front -and -not $back)) {
        [void]$marcados.Add($i)
    }
}

# ------------------------------------------------------------------------------
# INTERACTIVE TUI (Terminal User Interface) MENU
# ------------------------------------------------------------------------------
function Show-TerminalMenu {
    $cursorIndex = 0
    $running = $true

    # Hide standard console cursor
    [Console]::CursorVisible = $false

    while ($running) {
        Clear-Host
        Write-Host "==========================================================" -ForegroundColor Cyan
        Write-Host "             INSTALLATION PACKAGE SELECTION               " -ForegroundColor Cyan
        Write-Host "==========================================================" -ForegroundColor Cyan
        Write-Host " Use [Arrow Keys ^/v] to navigate" -ForegroundColor Gray
        Write-Host " Press [Space] to Toggle Selection" -ForegroundColor Gray
        Write-Host " Press [Enter] to Confirm | [Esc] to Cancel" -ForegroundColor Gray
        Write-Host "----------------------------------------------------------`n" -ForegroundColor Cyan

        for ($i = 0; $i -lt $catalogo.Count; $i++) {
            $item = $catalogo[$i]
            $check = if ($marcados.Contains($i)) { "[X]" } else { "[ ]" }
            $prefix = if ($i -eq $cursorIndex) { " > " } else { "   " }

            $linha = "$prefix$check [$($item.Categoria)] $($item.Nome)"

            if ($i -eq $cursorIndex) {
                Write-Host $linha -ForegroundColor Black -BackgroundColor Yellow
            } elseif ($marcados.Contains($i)) {
                Write-Host $linha -ForegroundColor Green
            } else {
                Write-Host $linha -ForegroundColor DarkGray
            }
        }

        # Read user key input
        $key = [Console]::ReadKey($true)

        switch ($key.Key) {
            "UpArrow" {
                if ($cursorIndex -gt 0) { $cursorIndex-- }
            }
            "DownArrow" {
                if ($cursorIndex -lt ($catalogo.Count - 1)) { $cursorIndex++ }
            }
            "Spacebar" {
                if ($marcados.Contains($cursorIndex)) {
                    [void]$marcados.Remove($cursorIndex)
                } else {
                    [void]$marcados.Add($cursorIndex)
                }
            }
            "Enter" {
                $running = $false
            }
            "Escape" {
                [Console]::CursorVisible = $true
                Write-Host "`nOperation cancelled by user." -ForegroundColor Red
                exit
            }
        }
    }

    [Console]::CursorVisible = $true
}

Show-TerminalMenu

$selecionados = foreach ($idx in $marcados) { $catalogo[$idx] }

if ($selecionados.Count -eq 0) {
    Write-Host "`nNo items selected." -ForegroundColor Red
    exit
}

# ------------------------------------------------------------------------------
# CONFIRMATION AND EXECUTION
# ------------------------------------------------------------------------------
$precisaWSL = $selecionados.ID -contains "WSL2"

Clear-Host
Write-Host "==================================================================" -ForegroundColor Red
Write-Host " The following items will be installed:" -ForegroundColor Yellow
$selecionados | ForEach-Object { Write-Host "  - [$($_.Categoria)] $($_.Nome)" -ForegroundColor Cyan }

if ($precisaWSL) {
    Write-Host "`n NOTE: WSL2 is selected. THE SYSTEM WILL REBOOT AT THE END." -ForegroundColor Red
}

Write-Host "==================================================================" -ForegroundColor Red
Write-Host "`nPress any key to START or 'Ctrl + C' to cancel..." -ForegroundColor Green
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# ------------------------------------------------------------------------------
# INSTALLATION PROCESS
# ------------------------------------------------------------------------------
Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "   Starting Dev Environment Configuration        " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$wingetArgs = @("--silent", "--accept-package-agreements", "--accept-source-agreements", "--ignore-security-hash", "--no-upgrade")
$vscodeOverride = '/VERYSILENT /NORESTART /MERGETASKS="!runcode,addcontextmenufiles,addcontextmenufolders,associatewithfiles"'

winget settings --enable InstallerHashOverride

# Update Winget sources to ensure latest packages are available
winget source update

foreach ($item in $selecionados) {
    Write-Host "`nInstalling: $($item.Nome)..." -ForegroundColor Yellow

    switch ($item.ID) {
        "Schniz.fnm" {
            winget install --id $item.ID $wingetArgs

            # Refresh PATH environment variable for the current script session to locate fnm executable
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

            # Ensure fnm command is accessible before proceeding
            if (Get-Command fnm -ErrorAction SilentlyContinue) {
                Write-Host "Configuring fnm and installing Node.js LTS..." -ForegroundColor Cyan

                # Initialize fnm environment for current PowerShell session
                fnm env --use-on-cd | Invoke-Expression

                # Install and set LTS version as default
                fnm install --lts
                fnm use lts-latest
                fnm default lts-latest

                # Refresh PATH again to ensure Node binaries (npm, npx, corepack) are accessible
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

                # Enable and activate pnpm via Corepack
                if (Get-Command corepack -ErrorAction SilentlyContinue) {
                    Write-Host "Enabling and activating pnpm via Corepack..." -ForegroundColor Cyan
                    corepack enable
                    corepack prepare pnpm@latest --activate
                    Write-Host "pnpm activated successfully!" -ForegroundColor Green
                } else {
                    Write-Host "WARNING: Corepack not found. Please install pnpm manually later." -ForegroundColor Yellow
                }

                Write-Host "Node.js LTS installed successfully!" -ForegroundColor Green
            } else {
                Write-Host "WARNING: Could not load fnm in the current session. Node.js must be installed manually." -ForegroundColor Yellow
            }
        }
        "PSModules" {
            # Force TLS 1.2 for modern repositories download without prompt issues
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

            # Install NuGet Package Provider silently
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ForceBootstrap -Scope AllUsers -ErrorAction SilentlyContinue

            # Trust PSGallery repository silently
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue

            # Install PowerShell Modules
            $modules = @("PSReadLine", "Terminal-Icons", "PSFzf")
            foreach ($mod in $modules) {
                Write-Host "Installing module: $mod..." -ForegroundColor Cyan
                Install-Module -Name $mod -Force -SkipPublisherCheck -AllowClobber -Scope AllUsers
            }

            # Install FiraCode and Meslo Nerd Fonts for Oh My Posh
            Write-Host "Installing FiraCode and Meslo Nerd Fonts..." -ForegroundColor Cyan
            oh-my-posh font install firacode
            oh-my-posh font install meslo

            # ------------------------------------------------------------------
            # POWERSHELL PROFILE CONFIGURATION ($PROFILE)
            # ------------------------------------------------------------------
            Write-Host "Configuring PowerShell profile file ($PROFILE)..." -ForegroundColor Cyan

            $ompConfigFile = Join-Path $PSScriptDir "montys-mod.omp.json"
            $userProfileDir = Split-Path -Parent $PROFILE

            if (-not (Test-Path $userProfileDir)) {
                New-Item -ItemType Directory -Path $userProfileDir -Force | Out-Null
            }

            if (Test-Path $ompConfigFile) {
                $targetOmpPath = Join-Path $userProfileDir "montys-mod.omp.json"
                Copy-Item -Path $ompConfigFile -Destination $targetOmpPath -Force
                $ompConfigFullPath = $targetOmpPath.Replace('\', '/')
                Write-Host "File 'montys-mod.omp.json' copied to: $targetOmpPath" -ForegroundColor Green
            } else {
                $ompConfigFullPath = "./montys-mod.omp.json"
                Write-Host "WARNING: 'montys-mod.omp.json' not found in '$PSScriptDir'." -ForegroundColor Yellow
            }

            # Write content to profile script
            $profileContent = @"
Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
    param(`$commandName, `$wordToComplete, `$cursorPosition)
    `$completion_file = New-TemporaryFile
    `$env:ARGCOMPLETE_USE_TEMPFILES = 1
    `$env:_ARGCOMPLETE_STDOUT_FILENAME = `$completion_file
    `$env:COMP_LINE = `$wordToComplete
    `$env:COMP_POINT = `$cursorPosition
    `$env:_ARGCOMPLETE = 1
    `$env:_ARGCOMPLETE_SUPPRESS_SPACE = 0
    `$env:_ARGCOMPLETE_IFS = "`n"
    `$env:_ARGCOMPLETE_SHELL = 'powershell'
    az 2>&1 | Out-Null
    Get-Content `$completion_file | Sort-Object | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new(`$_, `$_ , "ParameterValue", `$_)
    }
    Remove-Item `$completion_file, Env:\_ARGCOMPLETE_STDOUT_FILENAME, Env:\ARGCOMPLETE_USE_TEMPFILES, Env:\COMP_LINE, Env:\COMP_POINT, Env:\_ARGCOMPLETE, Env:\_ARGCOMPLETE_SUPPRESS_SPACE, Env:\_ARGCOMPLETE_IFS, Env:\_ARGCOMPLETE_SHELL
}

Import-Module -Name Terminal-Icons
Import-Module -Name PSReadLine
Import-Module -Name PSFzf

Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -MaximumHistoryCount 16384

Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

# Bind Ctrl+r to override default PSReadLine reverse history search
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

`$OhMyPoshConfig = '$ompConfigFullPath'
function omp {
    oh-my-posh init pwsh --config `$OhMyPoshConfig | Invoke-Expression
}
"@
            Set-Content -Path $PROFILE -Value $profileContent -Encoding UTF8 -Force
            Write-Host "PowerShell profile configured!" -ForegroundColor Green
        }
        "Microsoft.VisualStudioCode.Insiders" {
            winget install --id $item.ID $wingetArgs --override $vscodeOverride
        }
        "WSL2" {
            wsl --install --no-distribution
            wsl --install -d Ubuntu
        }
        Default {
            winget install --id $item.ID $wingetArgs
        }
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
    Pause
}

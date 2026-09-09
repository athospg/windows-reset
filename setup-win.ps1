<#
.SYNOPSIS
    Automation script for initial setup of the development environment on Windows.

.DESCRIPTION
    Installs CLI utilities, development tools, IDEs, browsers, and enables
    WSL2 with Ubuntu via an interactive terminal menu. After the app selection,
    a second menu lets the user toggle system tweaks (fonts, Node.js stack,
    PowerShell modules/profile).

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
    .\setup-pc.ps1 -front
    .\setup-pc.ps1 -back
    .\setup-pc.ps1 -front -back
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
    [Alias("h", "?", "-help")]
    [switch]$help
)

if ($help) {
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit
}

# 1. Ensure Administrator privileges
# Relaunch keeps the window open (-NoExit) so errors don't vanish instantly.
# Only pass -front/-back when true: PowerShell 5.1's -File mode cannot convert
# the string "False" into a [switch] parameter bound with ":$false".
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $relaunchArgs = "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($front) { $relaunchArgs += " -front" }
    if ($back) { $relaunchArgs += " -back" }
    if ($NoPwsh) { $relaunchArgs += " -NoPwsh" }
    if ($NoApps) { $relaunchArgs += " -NoApps" }
    if ($NoTweaks) { $relaunchArgs += " -NoTweaks" }

    Start-Process powershell $relaunchArgs -Verb RunAs
    exit
}

$PSScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ------------------------------------------------------------------------------
# SOFTWARE CATALOG
# ------------------------------------------------------------------------------
$catalogo = @(
    [PSCustomObject]@{ ID = "Microsoft.PowerShell";              Nome = "PowerShell 7";                  Categoria = "CLI"; Marcado = $false; Front = $true;  Back = $true  }
    [PSCustomObject]@{ ID = "Microsoft.WindowsTerminal.Preview"; Nome = "Windows Terminal Preview";      Categoria = "CLI"; Marcado = $false; Front = $true;  Back = $true  }
    [PSCustomObject]@{ ID = "Microsoft.WindowsTerminal";         Nome = "Windows Terminal";              Categoria = "CLI"; Marcado = $false; Front = $false; Back = $false }
    [PSCustomObject]@{ ID = "JanDeDobbeleer.OhMyPosh";           Nome = "Oh My Posh";                    Categoria = "CLI"; Marcado = $false; Front = $true;  Back = $true  }
    [PSCustomObject]@{ ID = "junegunn.fzf";                      Nome = "fzf (Fuzzy Finder)";            Categoria = "CLI"; Marcado = $false; Front = $true;  Back = $true  }
    [PSCustomObject]@{ ID = "Git.Git";                           Nome = "Git";                           Categoria = "Dev"; Marcado = $false; Front = $true;  Back = $true  }
    [PSCustomObject]@{ ID = "Fork.Fork";                         Nome = "Fork (Git Client)";             Categoria = "Dev"; Marcado = $false; Front = $true;  Back = $true  }
    [PSCustomObject]@{ ID = "Schniz.fnm";                        Nome = "fnm (Fast Node Manager)";       Categoria = "Dev"; Marcado = $false; Front = $true;  Back = $true  }
    [PSCustomObject]@{ ID = "CoreyButler.NVMforWindows";         Nome = "NVM for Windows";               Categoria = "Dev"; Marcado = $false; Front = $false; Back = $false }
    [PSCustomObject]@{ ID = "Microsoft.VisualStudioCode.Insiders"; Nome = "VS Code Insiders";            Categoria = "Dev"; Marcado = $false; Front = $true;  Back = $true  }
    [PSCustomObject]@{ ID = "Microsoft.VisualStudioCode";        Nome = "VS Code";                       Categoria = "Dev"; Marcado = $false; Front = $false; Back = $false }
    [PSCustomObject]@{ ID = "SUSE.RancherDesktop";               Nome = "Rancher Desktop";               Categoria = "Dev"; Marcado = $false; Front = $false; Back = $true  }
    [PSCustomObject]@{ ID = "dbeaver.dbeaver";                   Nome = "DBeaver Community";             Categoria = "Dev"; Marcado = $false; Front = $false; Back = $true  }
    [PSCustomObject]@{ ID = "Microsoft.DotNet.SDK.10";           Nome = ".NET SDK 10";                   Categoria = "Dev"; Marcado = $false; Front = $false; Back = $true  }
    [PSCustomObject]@{ ID = "Brave.Brave";                       Nome = "Brave Browser";                 Categoria = "Browser"; Marcado = $false; Front = $true;  Back = $true  }
    [PSCustomObject]@{ ID = "WSL2";                              Nome = "WSL2 + Ubuntu";                 Categoria = "System"; Marcado = $false; Front = $false; Back = $false }
)

# ------------------------------------------------------------------------------
# PRE-SELECTION FLAGS
# ------------------------------------------------------------------------------
for ($i = 0; $i -lt $catalogo.Count; $i++) {
    $item = $catalogo[$i]
    $item.Marcado = (
        ($front -and $back -and ($item.Front -or $item.Back)) -or
        ($front -and -not $back -and $item.Front) -or
        ($back -and -not $front -and $item.Back)
    )
}

# ------------------------------------------------------------------------------
# INTERACTIVE TUI (Terminal User Interface) MENU
# ------------------------------------------------------------------------------
function Show-TerminalMenu {
    param (
        [array]$Items,
        [string]$Title
    )

    # Use HashSet matching the count of the selection state
    $marcados = [System.Collections.Generic.HashSet[int]]::new()
    for ($i = 0; $i -lt $Items.Count; $i++) {
        if ($Items[$i].Marcado) { [void]$marcados.Add($i) }
    }

    $cursorIndex = 0
    $running = $true

    # Hide standard console cursor
    [Console]::CursorVisible = $false

    while ($running) {
        Clear-Host
        Write-Host "==========================================================" -ForegroundColor Cyan
        Write-Host "  $Title" -ForegroundColor Cyan
        Write-Host "==========================================================" -ForegroundColor Cyan
        Write-Host " Use [Arrow Keys ^/v] to navigate" -ForegroundColor Gray
        Write-Host " Press [Space] to Toggle Selection" -ForegroundColor Gray
        Write-Host " Press [Enter] to Confirm | [Esc] to Cancel" -ForegroundColor Gray
        Write-Host "----------------------------------------------------------`n" -ForegroundColor Cyan

        for ($i = 0; $i -lt $Items.Count; $i++) {
            $item = $Items[$i]
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
                if ($cursorIndex -lt ($Items.Count - 1)) { $cursorIndex++ }
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
    return $marcados
}

if ($NoApps) {
    Write-Host "Skipping app installations (-NoApps)." -ForegroundColor Yellow
    $selecionados = @()
} else {
    $appMarcados = Show-TerminalMenu -Items $catalogo -Title "INSTALLATION PACKAGE SELECTION"
    $selecionados = @($appMarcados | ForEach-Object { $catalogo[$_] })
}

# ------------------------------------------------------------------------------
# TWEAKS CATALOG (BUILT DYNAMICALLY)
# Selection state takes into account what is already installed on the system
# (winget list + Get-Command fallback) and what the user just selected to install.
# ------------------------------------------------------------------------------
$script:installedWingetLines = $null

function Test-WingetInstalled {
    param ([string]$Id)
    if ($null -eq $script:installedWingetLines) {
        Write-Host "Checking installed packages (winget list)..." -ForegroundColor Gray
        $script:installedWingetLines = (winget list --accept-source-agreements 2>$null | Out-String)
    }
    $escaped = [regex]::Escape($Id)
    [bool]($script:installedWingetLines -match $escaped)
}

# Cheap availability checks (Get-Command) always run - they feed the profile
# menu premarks too. The winget list scan only runs when the tweaks menu
# (menu 2) is actually shown; selecting apps counts as available otherwise.
$fnmAvailable = [bool](Get-Command fnm -ErrorAction SilentlyContinue)
$nvmAvailable = [bool](Get-Command nvm -ErrorAction SilentlyContinue)
$fzfAvailable = [bool](Get-Command fzf -ErrorAction SilentlyContinue)
$ompAvailable = [bool](Get-Command oh-my-posh -ErrorAction SilentlyContinue)

if (-not $NoTweaks) {
    $fnmAvailable = ($selecionados.ID -contains "Schniz.fnm") -or (Test-WingetInstalled "Schniz.fnm") -or $fnmAvailable
    $nvmAvailable = ($selecionados.ID -contains "CoreyButler.NVMforWindows") -or (Test-WingetInstalled "CoreyButler.NVMforWindows") -or $nvmAvailable
    $fzfAvailable = ($selecionados.ID -contains "junegunn.fzf") -or (Test-WingetInstalled "junegunn.fzf") -or $fzfAvailable
    $ompAvailable = ($selecionados.ID -contains "JanDeDobbeleer.OhMyPosh") -or (Test-WingetInstalled "JanDeDobbeleer.OhMyPosh") -or $ompAvailable
}

# Any Node version manager is enough for the Node.js tweaks to make sense
$nodeManagerAvailable = $fnmAvailable -or $nvmAvailable

$vscodeMenuScript = Join-Path $PSScriptDir "vscode-context-menu.ps1"
$vscodeAvailable = $false
if (-not $NoTweaks) {
    $vscodeAvailable = ($selecionados.ID -contains "Microsoft.VisualStudioCode") -or
        ($selecionados.ID -contains "Microsoft.VisualStudioCode.Insiders") -or
        (Test-WingetInstalled "Microsoft.VisualStudioCode") -or
        (Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe") -or
        (Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code Insiders\Code - Insiders.exe")
}


$nerdFontsUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download"

$tweaks = @(
    [PSCustomObject]@{ ID = "Font.FiraCode";      Nome = "FiraCode Nerd Font";       Categoria = "Fonts";  Variant = "FiraCode Nerd Font";     Url = "$nerdFontsUrl/FiraCode.zip";      Modulo = $null; Marcado = $false }
    [PSCustomObject]@{ ID = "Font.Meslo";         Nome = "MesloLGS Nerd Font";       Categoria = "Fonts";  Variant = "MesloLGS Nerd Font";     Url = "$nerdFontsUrl/Meslo.zip";         Modulo = $null; Marcado = $false }
    [PSCustomObject]@{ ID = "Font.JetBrainsMono"; Nome = "JetBrainsMono Nerd Font";  Categoria = "Fonts";  Variant = "JetBrainsMono Nerd Font"; Url = "$nerdFontsUrl/JetBrainsMono.zip"; Modulo = $null; Marcado = $false }
    [PSCustomObject]@{ ID = "Font.CascadiaCode";  Nome = "CascadiaCode Nerd Font";   Categoria = "Fonts";  Variant = "CaskaydiaCove Nerd Font"; Url = "$nerdFontsUrl/CascadiaCode.zip";  Modulo = $null; Marcado = $false }
    [PSCustomObject]@{ ID = "Font.Hack";          Nome = "Hack Nerd Font";           Categoria = "Fonts";  Variant = "Hack Nerd Font";          Url = "$nerdFontsUrl/Hack.zip";          Modulo = $null; Marcado = $false }
    [PSCustomObject]@{ ID = "Tweak.NodeLTS";      Nome = "Node.js LTS (fnm or nvm-windows)"; Categoria = "Runtime";  Variant = $null; Url = $null; Modulo = $null; Marcado = $nodeManagerAvailable }
    [PSCustomObject]@{ ID = "Tweak.pnpm";         Nome = "pnpm activation (requires Node.js LTS above)"; Categoria = "Runtime"; Variant = $null; Url = $null; Modulo = $null; Marcado = $nodeManagerAvailable }
    [PSCustomObject]@{ ID = "Tweak.OpenCode";     Nome = "OpenCode AI agent (requires Node.js LTS above)"; Categoria = "Runtime"; Variant = $null; Url = $null; Modulo = $null; Marcado = $nodeManagerAvailable }
    [PSCustomObject]@{ ID = "Module.PSReadLine";      Nome = "Module PSReadLine";     Categoria = "PowerShell"; Variant = $null; Url = $null; Modulo = "PSReadLine";      Marcado = (-not ([bool](Get-Module -ListAvailable -Name PSReadLine -ErrorAction SilentlyContinue))) }
    [PSCustomObject]@{ ID = "Module.TerminalIcons";   Nome = "Module Terminal-Icons"; Categoria = "PowerShell"; Variant = $null; Url = $null; Modulo = "Terminal-Icons";  Marcado = (-not ([bool](Get-Module -ListAvailable -Name Terminal-Icons -ErrorAction SilentlyContinue))) }
    [PSCustomObject]@{ ID = "Module.PSFzf";           Nome = "Module PSFzf";          Categoria = "PowerShell"; Variant = $null; Url = $null; Modulo = "PSFzf";           Marcado = $fzfAvailable -and (-not ([bool](Get-Module -ListAvailable -Name PSFzf -ErrorAction SilentlyContinue))) }
    [PSCustomObject]@{ ID = "Tweak.VSCodeMenu";   Nome = "VS Code context menu entries"; Categoria = "Shell";   Variant = $null; Url = $null; Modulo = $null; Marcado = $vscodeAvailable }
)

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
# 3. POWERSHELL PROFILE SELECTION (third menu)
# The actual profile writing happens later, during execution, so the
# confirmation screen can list everything (apps + tweaks + profile blocks).
# Each generated block is wrapped in start/end markers so the profile is
# MERGED instead of overwritten: manual configuration placed outside the
# markers is always preserved as-is. Blocks already present are replaced
# in-place; unmarked existing content is never touched.
# ------------------------------------------------------------------------------
# Modules selected in the tweaks menu drive the profile block premarks
$selectedModules = @($tweaksSelecionados | Where-Object { $_.ID -like "Module.*" } | ForEach-Object { $_.Modulo })

# Chosen profile block ids (populated by the menu below; empty with -NoPwsh)
$chosenBlockIds = @()

function Get-ProfileBlock {
    param ([string]$Id)
    switch ($Id) {
        "fnm" {
            return @'
# Initialize FNM (Fast Node Manager) environment
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
}
'@
        }
        "omp" {
            return @'
# Oh My Posh prompt (loaded manually with 'omp')
$OhMyPoshConfig = '{{OMP_CONFIG_PATH}}'
function omp {
    oh-my-posh init pwsh --config $OhMyPoshConfig | Invoke-Expression
}
'@
        }
        "az" {
            return @'
Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)
    $completion_file = New-TemporaryFile
    $env:ARGCOMPLETE_USE_TEMPFILES = 1
    $env:_ARGCOMPLETE_STDOUT_FILENAME = $completion_file
    $env:COMP_LINE = $wordToComplete
    $env:COMP_POINT = $cursorPosition
    $env:_ARGCOMPLETE = 1
    $env:_ARGCOMPLETE_SUPPRESS_SPACE = 0
    $env:_ARGCOMPLETE_IFS = "`n"
    $env:_ARGCOMPLETE_SHELL = 'powershell'
    az 2>&1 | Out-Null
    Get-Content $completion_file | Sort-Object | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_ , "ParameterValue", $_)
    }
    Remove-Item $completion_file, Env:\_ARGCOMPLETE_STDOUT_FILENAME, Env:\ARGCOMPLETE_USE_TEMPFILES, Env:\COMP_LINE, Env:\COMP_POINT, Env:\_ARGCOMPLETE, Env:\_ARGCOMPLETE_SUPPRESS_SPACE, Env:\_ARGCOMPLETE_IFS, Env:\_ARGCOMPLETE_SHELL
}
'@
        }
        "psreadline" {
            return @'
Import-Module -Name PSReadLine
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -MaximumHistoryCount 16384
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete
'@
        }
        "terminal-icons" {
            return "Import-Module -Name Terminal-Icons"
        }
        "psfzf" {
            return @'
Import-Module -Name PSFzf
# Bind Ctrl+r to override default PSReadLine reverse history search
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
'@
        }
    }
    return ""
}

if (-not $NoPwsh) {
    $profileBlocks = @(
        [PSCustomObject]@{ Id = "omp";            Nome = "Oh My Posh theme + omp function";    Categoria = "Prompt";  Marcado = $ompAvailable }
        [PSCustomObject]@{ Id = "fnm";            Nome = "FNM initialization";                 Categoria = "Runtime"; Marcado = ($tweaksSelecionados.ID -contains "Tweak.NodeLTS") }
        [PSCustomObject]@{ Id = "psreadline";     Nome = "PSReadLine import + options";        Categoria = "Module";  Marcado = ($selectedModules -contains "PSReadLine") }
        [PSCustomObject]@{ Id = "terminal-icons"; Nome = "Terminal-Icons import";              Categoria = "Module";  Marcado = ($selectedModules -contains "Terminal-Icons") }
        [PSCustomObject]@{ Id = "psfzf";          Nome = "PSFzf import + key bindings";        Categoria = "Module";  Marcado = ($selectedModules -contains "PSFzf") }
        [PSCustomObject]@{ Id = "az";             Nome = "Azure CLI argument completer";       Categoria = "CLI";     Marcado = ([bool](Get-Command az -ErrorAction SilentlyContinue)) }
    )

    $profileBlockIndices = Show-TerminalMenu -Items $profileBlocks -Title "POWERSHELL PROFILE CONFIGURATION"
    $chosenBlockIds = @($profileBlockIndices | ForEach-Object { $profileBlocks[$_].Id })
} else {
    Write-Host "Skipping PowerShell profile configuration (-NoPwsh)." -ForegroundColor Yellow
}

# ------------------------------------------------------------------------------
# CONFIRMATION AND EXECUTION
# The confirmation runs after ALL menus so the summary covers everything
# that will be processed: apps, system tweaks and profile blocks.
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

# ------------------------------------------------------------------------------
# INSTALLATION PROCESS
# ------------------------------------------------------------------------------
Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "   Starting Dev Environment Configuration        " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

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

# ------------------------------------------------------------------------------
# NERD FONTS INSTALLATION
# ------------------------------------------------------------------------------
function Install-NerdFont {
    param (
        [string]$Variant,
        [string]$Url
    )

    # Unique extraction folder per variant to avoid cross-call interference
    $extractDir = Join-Path $env:TEMP "NerdFonts\$($Variant -replace ' ', '')"
    $zipPath = "$extractDir.zip"

    if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue }

    Invoke-WebRequest -Uri $Url -OutFile $zipPath -UseBasicParsing
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

    # Install every font family shipped in the zip (base, Mono and Propo
    # flavours) since the selected font may be used anywhere in Windows.
    $ttfFiles = Get-ChildItem -Path $extractDir -Recurse -Filter *.ttf

    if ($ttfFiles.Count -eq 0) {
        Write-Host "WARNING: No fonts found in: $extractDir" -ForegroundColor Yellow
        return
    }

    # Shell COM copy into the Fonts folder registers each font with its
    # full title/weight in the system (HKLM Fonts registry)
    $shell = New-Object -ComObject Shell.Application
    $fontsFolder = $shell.Namespace(0x14)

    $installed = 0
    foreach ($ttf in $ttfFiles) {
        if (-not (Test-Path "$env:windir\Fonts\$($ttf.Name)")) {
            $fontsFolder.CopyHere($ttf.FullName, 0x14)
            $installed++
        }
    }

    # CopyHere is asynchronous; wait until every font file exists
    $attempts = 0
    while (($ttfFiles | Where-Object { -not (Test-Path "$env:windir\Fonts\$($_.Name)") }).Count -gt 0 -and $attempts -lt 10) {
        Start-Sleep -Seconds 2
        $attempts++
    }

    Write-Host "Installed $installed fonts of variant '$Variant'." -ForegroundColor Green

    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
}

# ------------------------------------------------------------------------------
# APP INSTALLATION
# ------------------------------------------------------------------------------
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
# SYSTEM TWEAKS APPLICATION
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

    # 4.4 Install PowerShell Modules silently (Windows PowerShell 5.1 scope)
    foreach ($mod in $selectedModules) {
        Write-Host "Installing module: $mod..." -ForegroundColor Cyan
        Install-Module -Name $mod -Force -SkipPublisherCheck -AllowClobber -Scope AllUsers -Confirm:$false
    }

    # 4.5 Install the same modules into PowerShell 7's module directory
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        foreach ($mod in $selectedModules) {
            Write-Host "Installing module for PowerShell 7: $mod..." -ForegroundColor Cyan
            pwsh -NoProfile -Command "Install-Module -Name $mod -Force -SkipPublisherCheck -AllowClobber -Scope AllUsers -Confirm:`$false"
        }
    }
}

# 5. Profile merge/write (the selection happened in menu 3; -NoPwsh never writes)
if (-not $NoPwsh) {
    if ($chosenBlockIds.Count -gt 0) {
        # Merge function: preserves content outside markers, replaces marked
        # regions in-place and appends blocks that are missing. Escapes any
        # '$' in the new region before regex replace to avoid .NET treating
        # "$_" etc. as capture-group references.
        function Merge-ProfileBlock {
            param ([string]$Path, [string[]]$BlockIds, [string]$OmpPathValue)

            $content = if (Test-Path $Path) { Get-Content -Raw $Path } else { "" }

            foreach ($profileBlock in $profileBlocks) {
                if (-not ($BlockIds -contains $profileBlock.Id)) { continue }

                $markerStart = "# >>> setup-pc: $($profileBlock.Id) >>>"
                $markerEnd = "# <<< setup-pc: $($profileBlock.Id) <<<"
                $body = Get-ProfileBlock -Id $profileBlock.Id
                if ($profileBlock.Id -eq "omp") {
                    $body = $body.Replace("{{OMP_CONFIG_PATH}}", $OmpPathValue)
                }
                $newRegion = "$markerStart`r`n$body`r`n$markerEnd"
                # Regex replace needs '$' escaped ('$' -> '$$') or .NET treats
                # "$_" like capture-group references. The append branch must
                # receive the unescaped region instead.
                $newRegionEscaped = $newRegion.Replace('$', '$$')

                $pattern = "(?s)" + [regex]::Escape($markerStart) + "[\s\S]*?" + [regex]::Escape($markerEnd) + "\r?\n?"

                if ($content -match $pattern) {
                    $content = [regex]::Replace($content, $pattern, $newRegionEscaped)
                } else {
                    if ($content.TrimEnd("`r", "`n") -ne "") {
                        $content = $content.TrimEnd("`r", "`n") + "`r`n`r`n"
                    }
                    $content += $newRegion
                }
            }

            return $content.TrimEnd("`r", "`n") + "`r`n"
        }

        # Target profiles:
        # - session running PowerShell 7 -> write only $PROFILE (already the PS7 one)
        # - session running Windows PowerShell 5.1 -> write 5.1 $PROFILE + the PS7 one
        $profileTargets = [System.Collections.Generic.List[string]]::new()
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            [void]$profileTargets.Add($PROFILE)
        } else {
            [void]$profileTargets.Add($PROFILE)

            $docsDir = [Environment]::GetFolderPath('MyDocuments')
            [void]$profileTargets.Add((Join-Path $docsDir "PowerShell\Microsoft.PowerShell_profile.ps1"))
        }

        # Copy the Oh My Posh theme next to every profile dir when the omp
        # block is selected, resolving the config path per target
        $ompConfigSourceFile = Join-Path $PSScriptDir "montys-mod.omp.json"

        foreach ($target in $profileTargets) {
            $targetDir = Split-Path -Parent $target
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }

            $ompPathValue = ""
            if ($chosenBlockIds -contains "omp") {
                if (Test-Path $ompConfigSourceFile) {
                    $ompCopy = Join-Path $targetDir "montys-mod.omp.json"
                    Copy-Item -Path $ompConfigSourceFile -Destination $ompCopy -Force
                    $ompPathValue = $ompCopy.Replace('\', '/')
                    Write-Host "File 'montys-mod.omp.json' copied to: $ompCopy" -ForegroundColor Green
                } else {
                    Write-Host "WARNING: 'montys-mod.omp.json' not found in '$PSScriptDir'." -ForegroundColor Yellow
                }
            }

            $mergedContent = Merge-ProfileBlock -Path $target -BlockIds $chosenBlockIds -OmpPathValue $ompPathValue
            Set-Content -Path $target -Value $mergedContent -Encoding UTF8 -Force
            Write-Host "PowerShell profile updated: $target" -ForegroundColor Green
        }

        Write-Host "PowerShell profile configuration completed!" -ForegroundColor Green
    } else {
        Write-Host "No profile blocks selected. Profile untouched." -ForegroundColor Yellow
    }
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

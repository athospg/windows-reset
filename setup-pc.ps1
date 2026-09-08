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
    [PSCustomObject]@{ ID = "Microsoft.PowerShell";              Nome = "PowerShell 7";                  Categoria = "CLI"; Marcado = $false; Front = $true;  Back = $true  }
    [PSCustomObject]@{ ID = "Microsoft.WindowsTerminal.Preview"; Nome = "Windows Terminal Preview";      Categoria = "CLI"; Marcado = $false; Front = $true;  Back = $true  }
    [PSCustomObject]@{ ID = "Microsoft.WindowsTerminal";         Nome = "Windows Terminal";              Categoria = "CLI"; Marcado = $false; Front = $false; Back = $false }
    [PSCustomObject]@{ ID = "JanDeDobbeleer.OhMyPosh";           Nome = "Oh My Posh";                    Categoria = "CLI"; Marcado = $false; Front = $true;  Back = $true  }
    [PSCustomObject]@{ ID = "junegunn.fzf";                      Nome = "fzf (Fuzzy Finder)";            Categoria = "CLI"; Marcado = $false; Front = $true;  Back = $true  }
    [PSCustomObject]@{ ID = "Git.Git";                           Nome = "Git";                           Categoria = "Dev"; Marcado = $false; Front = $true;  Back = $true  }
    [PSCustomObject]@{ ID = "Fork.Fork";                         Nome = "Fork (Git Client)";             Categoria = "Dev"; Marcado = $false; Front = $true;  Back = $true  }
    [PSCustomObject]@{ ID = "Schniz.fnm";                        Nome = "fnm (Fast Node Manager)";       Categoria = "Dev"; Marcado = $false; Front = $true;  Back = $true  }
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

$appMarcados = Show-TerminalMenu -Items $catalogo -Title "INSTALLATION PACKAGE SELECTION"
$selecionados = @($appMarcados | ForEach-Object { $catalogo[$_] })

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

$fnmAvailable = ($selecionados.ID -contains "Schniz.fnm") -or (Test-WingetInstalled "Schniz.fnm") -or ([bool](Get-Command fnm -ErrorAction SilentlyContinue))
$fzfAvailable = ($selecionados.ID -contains "junegunn.fzf") -or (Test-WingetInstalled "junegunn.fzf") -or ([bool](Get-Command fzf -ErrorAction SilentlyContinue))
$ompAvailable = ($selecionados.ID -contains "JanDeDobbeleer.OhMyPosh") -or (Test-WingetInstalled "JanDeDobbeleer.OhMyPosh") -or ([bool](Get-Command oh-my-posh -ErrorAction SilentlyContinue))

$vscodeMenuScript = Join-Path $PSScriptDir "vscode-context-menu.ps1"
$vscodeAvailable = ($selecionados.ID -contains "Microsoft.VisualStudioCode") -or
    ($selecionados.ID -contains "Microsoft.VisualStudioCode.Insiders") -or
    (Test-WingetInstalled "Microsoft.VisualStudioCode") -or
    (Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe") -or
    (Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code Insiders\Code - Insiders.exe")


$nerdFontsUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download"

$tweaks = @(
    [PSCustomObject]@{ ID = "Font.FiraCode";      Nome = "FiraCode Nerd Font";       Categoria = "Fonts";  Variant = "FiraCode Nerd Font";     Url = "$nerdFontsUrl/FiraCode.zip";      Modulo = $null; Marcado = $false }
    [PSCustomObject]@{ ID = "Font.Meslo";         Nome = "MesloLGS Nerd Font";       Categoria = "Fonts";  Variant = "MesloLGS Nerd Font";     Url = "$nerdFontsUrl/Meslo.zip";         Modulo = $null; Marcado = $false }
    [PSCustomObject]@{ ID = "Font.JetBrainsMono"; Nome = "JetBrainsMono Nerd Font";  Categoria = "Fonts";  Variant = "JetBrainsMono Nerd Font"; Url = "$nerdFontsUrl/JetBrainsMono.zip"; Modulo = $null; Marcado = $false }
    [PSCustomObject]@{ ID = "Font.CascadiaCode";  Nome = "CascadiaCode Nerd Font";   Categoria = "Fonts";  Variant = "CaskaydiaCove Nerd Font"; Url = "$nerdFontsUrl/CascadiaCode.zip";  Modulo = $null; Marcado = $false }
    [PSCustomObject]@{ ID = "Font.Hack";          Nome = "Hack Nerd Font";           Categoria = "Fonts";  Variant = "Hack Nerd Font";          Url = "$nerdFontsUrl/Hack.zip";          Modulo = $null; Marcado = $false }
    [PSCustomObject]@{ ID = "Tweak.NodeLTS";      Nome = "Node.js LTS via fnm";      Categoria = "Runtime";  Variant = $null; Url = $null; Modulo = $null; Marcado = $fnmAvailable }
    [PSCustomObject]@{ ID = "Tweak.pnpm";         Nome = "pnpm activation (requires Node.js LTS above)"; Categoria = "Runtime"; Variant = $null; Url = $null; Modulo = $null; Marcado = $fnmAvailable }
    [PSCustomObject]@{ ID = "Module.PSReadLine";      Nome = "Module PSReadLine";     Categoria = "PowerShell"; Variant = $null; Url = $null; Modulo = "PSReadLine";      Marcado = (-not ([bool](Get-Module -ListAvailable -Name PSReadLine -ErrorAction SilentlyContinue))) }
    [PSCustomObject]@{ ID = "Module.TerminalIcons";   Nome = "Module Terminal-Icons"; Categoria = "PowerShell"; Variant = $null; Url = $null; Modulo = "Terminal-Icons";  Marcado = (-not ([bool](Get-Module -ListAvailable -Name Terminal-Icons -ErrorAction SilentlyContinue))) }
    [PSCustomObject]@{ ID = "Module.PSFzf";           Nome = "Module PSFzf";          Categoria = "PowerShell"; Variant = $null; Url = $null; Modulo = "PSFzf";           Marcado = $fzfAvailable -and (-not ([bool](Get-Module -ListAvailable -Name PSFzf -ErrorAction SilentlyContinue))) }
    [PSCustomObject]@{ ID = "Tweak.VSCodeMenu";   Nome = "VS Code context menu entries"; Categoria = "Shell";   Variant = $null; Url = $null; Modulo = $null; Marcado = $vscodeAvailable }
)

$tweakMarcados = Show-TerminalMenu -Items $tweaks -Title "SYSTEM TWEAKS SELECTION"
$tweaksSelecionados = @($tweakMarcados | ForEach-Object { $tweaks[$_] })

# pnpm requires the Node.js LTS tweak to be selected
if ($tweaksSelecionados.ID -contains "Tweak.pnpm" -and -not ($tweaksSelecionados.ID -contains "Tweak.NodeLTS")) {
    $tweaksSelecionados = @($tweaksSelecionados | Where-Object { $_.ID -ne "Tweak.pnpm" })
    Write-Host "`nNOTE: pnpm was skipped because Node.js LTS was not selected." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
}

# Warn about PSFzf module without the fzf binary
if ($tweaksSelecionados.ID -contains "Module.PSFzf" -and -not $fzfAvailable) {
    Write-Host "`nNOTE: PSFzf selected, but the fzf binary was not found. PSFzf key bindings will warn at runtime." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
}

if ($selecionados.Count -eq 0 -and $tweaksSelecionados.Count -eq 0) {
    Write-Host "`nNo items selected." -ForegroundColor Red
    exit
}

# ------------------------------------------------------------------------------
# CONFIRMATION AND EXECUTION
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

# VS Code installs interactively so the user picks the installer options
# (context menu entries, file associations, PATH) themselves in the wizard
$vscodeArgs = @("--interactive", "--accept-package-agreements", "--accept-source-agreements")

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

# 2. Node.js LTS via fnm
if ($tweaksSelecionados.ID -contains "Tweak.NodeLTS") {
    $fnmCmd = Get-Command fnm -ErrorAction SilentlyContinue
    if ($fnmCmd) {
        Write-Host "`nConfiguring fnm and installing Node.js LTS..." -ForegroundColor Cyan

        # Initialize fnm environment for current PowerShell session
        fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression

        # Install and set LTS version as default
        fnm install --lts
        fnm use lts-latest
        fnm default lts-latest

        # Refresh PATH again to ensure Node binaries (npm, npx, corepack) are accessible
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        Write-Host "Node.js LTS installed successfully!" -ForegroundColor Green
    } else {
        Write-Host "WARNING: fnm not found. Node.js must be installed manually." -ForegroundColor Yellow
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

# 4. PowerShell modules (installed into both hosts when PowerShell 7 exists)
$selectedModules = @($tweaksSelecionados | Where-Object { $_.ID -like "Module.*" } | ForEach-Object { $_.Modulo })

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

# 5. PowerShell Profile generation (built only from the selected tweaks)
if ($selectedModules.Count -gt 0) {
    Write-Host "Configuring PowerShell profile ($PROFILE)..." -ForegroundColor Cyan

    $profileParts = [System.Collections.Generic.List[string]]::new()

    # FNM initialization block (only when the Node.js tweak was selected)
    if ($tweaksSelecionados.ID -contains "Tweak.NodeLTS") {
        $profileParts.Add(@"
# Initialize FNM (Fast Node Manager) environment
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
}
"@)
    }

    if ($ompAvailable) {
        $profileParts.Add(@"
# Oh My Posh prompt (loaded manually with 'omp')
`$OhMyPoshConfig = '$ompProfilePath'
function omp {
    oh-my-posh init pwsh --config `$OhMyPoshConfig | Invoke-Expression
}
"@)
    }

    $profileParts.Add(@"
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
"@)

    if ($selectedModules -contains "Terminal-Icons") {
        $profileParts.Add("Import-Module -Name Terminal-Icons")
    }

    if ($selectedModules -contains "PSReadLine") {
        $profileParts.Add(@"
Import-Module -Name PSReadLine
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -MaximumHistoryCount 16384
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete
"@)
    }

    if ($selectedModules -contains "PSFzf") {
        $profileParts.Add(@"
Import-Module -Name PSFzf
# Bind Ctrl+r to override default PSReadLine reverse history search
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
"@)
    }

    $profileContent = ($profileParts -join "`n`n") + "`n"

    # Copy Oh My Posh theme next to the profile when applicable
    $ompConfigFile = Join-Path $PSScriptDir "montys-mod.omp.json"
    $userProfileDir = Split-Path -Parent $PROFILE

    if (-not (Test-Path $userProfileDir)) {
        New-Item -ItemType Directory -Path $userProfileDir -Force | Out-Null
    }

    $ompConfigFullPath = $null
    if ($ompAvailable -and (Test-Path $ompConfigFile)) {
        $targetOmpPath = Join-Path $userProfileDir "montys-mod.omp.json"
        Copy-Item -Path $ompConfigFile -Destination $targetOmpPath -Force
        $ompConfigFullPath = $targetOmpPath.Replace('\', '/')
        Write-Host "File 'montys-mod.omp.json' copied to: $targetOmpPath" -ForegroundColor Green
    }
    elseif ($ompAvailable) {
        Write-Host "WARNING: 'montys-mod.omp.json' not found in '$PSScriptDir'." -ForegroundColor Yellow
    }

    # Replace the OMP config placeholder with the absolute path
    $profileContent = $profileContent.Replace('$ompProfilePath', $ompConfigFullPath)

    # Write profile for Windows PowerShell 5.1
    Set-Content -Path $PROFILE -Value $profileContent -Encoding UTF8 -Force
    Write-Host "PowerShell profile configured!" -ForegroundColor Green

    # PowerShell 7 uses a separate profile location - apply the same content
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        $docsDir = [Environment]::GetFolderPath('MyDocuments')
        $pwshProfileDir = Join-Path $docsDir "PowerShell"
        if (-not (Test-Path $pwshProfileDir)) {
            New-Item -ItemType Directory -Path $pwshProfileDir -Force | Out-Null
        }

        if ($ompConfigFullPath) {
            Copy-Item -Path $ompConfigFile -Destination (Join-Path $pwshProfileDir "montys-mod.omp.json") -Force
        }

        Set-Content -Path (Join-Path $pwshProfileDir "Microsoft.PowerShell_profile.ps1") -Value $profileContent -Encoding UTF8 -Force
        Write-Host "PowerShell 7 profile configured!" -ForegroundColor Green
    } else {
        Write-Host "WARNING: PowerShell 7 not found. Its profile must be configured manually." -ForegroundColor Yellow
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

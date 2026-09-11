<#
.SYNOPSIS
    Installed-package detection helpers.

.DESCRIPTION
    'Test-WingetInstalled' checks whether a package id is present on the
    machine via a single memoized 'winget list' enumeration.
    'Get-InstalledAvailability' resolves the "available" flags used by the
    tweak pre-marks: cheap Get-Command checks always run, while the winget
    scan (and "will be installed" lookups) only run when the tweaks menu
    is actually shown (-SkipWingetScan mirrors the -NoTweaks flag).
#>

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

function Get-InstalledAvailability {
    param (
        # App ids selected in menu 1 count as "will be installed"
        [array]$Selecionados,
        # When true, skip the winget list scan entirely (-NoTweaks)
        [switch]$SkipWingetScan
    )

    # Cheap Get-Command checks always run - they also feed the profile
    # menu premarks (blocks like the omp function / fnm init)
    $fnmAvailable = [bool](Get-Command fnm -ErrorAction SilentlyContinue)
    $nvmAvailable = [bool](Get-Command nvm -ErrorAction SilentlyContinue)
    $fzfAvailable = [bool](Get-Command fzf -ErrorAction SilentlyContinue)
    $ompAvailable = [bool](Get-Command oh-my-posh -ErrorAction SilentlyContinue)

    if (-not $SkipWingetScan) {
        $fnmAvailable = ($Selecionados.ID -contains "Schniz.fnm") -or (Test-WingetInstalled "Schniz.fnm") -or $fnmAvailable
        $nvmAvailable = ($Selecionados.ID -contains "CoreyButler.NVMforWindows") -or (Test-WingetInstalled "CoreyButler.NVMforWindows") -or $nvmAvailable
        $fzfAvailable = ($Selecionados.ID -contains "junegunn.fzf") -or (Test-WingetInstalled "junegunn.fzf") -or $fzfAvailable
        $ompAvailable = ($Selecionados.ID -contains "JanDeDobbeleer.OhMyPosh") -or (Test-WingetInstalled "JanDeDobbeleer.OhMyPosh") -or $ompAvailable
    }

    # Any Node version manager is enough for the Node.js tweaks to make sense
    $nodeManagerAvailable = $fnmAvailable -or $nvmAvailable

    $vscodeAvailable = $false
    if (-not $SkipWingetScan) {
        $vscodeAvailable = ($Selecionados.ID -contains "Microsoft.VisualStudioCode") -or
            ($Selecionados.ID -contains "Microsoft.VisualStudioCode.Insiders") -or
            (Test-WingetInstalled "Microsoft.VisualStudioCode") -or
            (Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe") -or
            (Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code Insiders\Code - Insiders.exe")
    }

    return [PSCustomObject]@{
        Fnm                   = $fnmAvailable
        Nvm                   = $nvmAvailable
        Fzf                   = $fzfAvailable
        Omp                   = $ompAvailable
        NodeManager           = $nodeManagerAvailable
        Vscode                = $vscodeAvailable
    }
}

$script:nodeAvailableChecked = $false
$script:nodeAvailable = $false

function Test-NodeAvailable {
    # Memoized: is a working Node.js/npm runtime present, no matter where it
    # came from (system PATH, MSI, fnm-managed or nvm-managed)?
    if ($script:nodeAvailableChecked) { return $script:nodeAvailable }

    $available = $false

    # 1. npm callable in the current session?
    # (Get-Command guard prevents reading a stale $LASTEXITCODE when the
    # shim does not exist at all)
    if ([bool](Get-Command npm -ErrorAction SilentlyContinue)) {
        $version = & npm -v 2>$null
        if ($LASTEXITCODE -eq 0 -and $version) { $available = $true }
    }

    # 2. fnm-managed runtime: the session PATH may not include the fnm
    #    "multishell" entry yet (fnm env runs later, during execution), so
    #    probe the version directly instead of relying on PATH
    if (-not $available -and [bool](Get-Command fnm -ErrorAction SilentlyContinue)) {
        # 'fnm exec' without --using resolves the default version
        & fnm exec -- npm -v 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            & fnm exec --using=lts-latest -- npm -v 2>$null | Out-Null
        }
        $available = ($LASTEXITCODE -eq 0)
    }

    # 3. nvm-windows-managed node (symlink PATH entry on machine PATH)
    if (-not $available -and [bool](Get-Command nvm -ErrorAction SilentlyContinue)) {
        $current = & nvm current 2>$null
        $available = ($LASTEXITCODE -eq 0 -and $current -and ($current -join "").Trim() -notmatch "^(none|inactive|\s)*$")
    }

    $script:nodeAvailable = $available
    $script:nodeAvailableChecked = $true
    return $available
}

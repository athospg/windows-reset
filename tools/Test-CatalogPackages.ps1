<#
.SYNOPSIS
    Validates every winget package used by the setup catalog without
    installing anything.

.DESCRIPTION
    Community winget manifests change and disappear over time (the NVM
    manifest once lagged two major versions behind), so this preflight checks
    the catalog before a real setup run.

    Two levels:
    - Level A (always): `winget show --id <ID> -e` must resolve the package.
    - Level B (-CheckScope): for rows declaring Scope = "user", a
      `winget download --id <ID> --scope user` must succeed. The download is
      discarded afterwards. winget only accepts --scope when the manifest
      declares a matching installer, which is exactly what we want to verify.

    Nothing is installed and no system setting changes. Downloads can be
    large (Build Tools, Go); use -SkipDownload to opt specific IDs out.

    Usage:
        pwsh -NoProfile -File tools/Test-CatalogPackages.ps1
        pwsh -NoProfile -File tools/Test-CatalogPackages.ps1 -CheckScope
        pwsh -NoProfile -File tools/Test-CatalogPackages.ps1 -Ids Git.Git,jqlang.jq
#>

[CmdletBinding()]
param (
    # Restrict the check to these package IDs (default: the whole catalog)
    [string[]]$Ids,
    # Also verify the user-scope support through winget download
    [switch]$CheckScope,
    # IDs to skip in the download check (large installers)
    [string[]]$SkipDownload = @(),
    # Where the temporary downloads go
    [string]$TempDir = (Join-Path $env:TEMP "setup-pc-scope-check")
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: winget not found in PATH. Run this on Windows with App Installer." -ForegroundColor Red
    exit 2
}

$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $repoRoot "invoke/catalog.ps1")
. (Join-Path $repoRoot "invoke/winget.ps1")

$apps = Get-AppCatalog | Where-Object { $_.ID -ne "WSL2" } # WSL2 is not a winget package
if ($Ids) {
    $apps = $apps | Where-Object { $Ids -contains $_.ID }
}
if (-not $apps) {
    Write-Host "No catalog packages matched the filter." -ForegroundColor Yellow
    exit 0
}

$results = [System.Collections.Generic.List[object]]::new()

foreach ($item in $apps) {
    # Level A: does the package ID still resolve?
    Write-Host "show  $($item.ID)..." -ForegroundColor Cyan -NoNewline
    winget show --id $item.ID --exact --accept-source-agreements *> $null
    $resolved = ($LASTEXITCODE -eq 0)
    if ($resolved) { Write-Host " OK" -ForegroundColor Green } else { Write-Host " NOT FOUND" -ForegroundColor Red }

    $current = [PSCustomObject]@{
        ID       = $item.ID
        Resolved = $resolved
        Scope    = if ($item.PSObject.Properties.Name -contains "Scope") { $item.Scope } else { "" }
        ScopeOK  = $null
    }
    $results.Add($current)

    # Level B: does the declared user scope actually work?
    $hasUserScope = ($item.PSObject.Properties.Name -contains "Scope") -and $item.Scope -eq "user"
    if ($resolved -and $CheckScope -and $hasUserScope -and ($SkipDownload -notcontains $item.ID)) {
        Write-Host "scope $($item.ID)..." -ForegroundColor Cyan -NoNewline
        if (Test-Path $TempDir) { Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue }

        $downloadArgs = @("download", "--id", $item.ID, "--exact", "--scope", "user",
            "--download-directory", $TempDir, "--accept-source-agreements",
            "--accept-package-agreements", "--disable-interactivity")
        winget @downloadArgs *> $null
        $scopeOk = ($LASTEXITCODE -eq 0)

        if ($scopeOk) { Write-Host " USER OK" -ForegroundColor Green } else { Write-Host " USER UNSUPPORTED" -ForegroundColor Red }
        $current.ScopeOK = $scopeOk

        if (Test-Path $TempDir) { Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

$failed = @($results | Where-Object { -not $_.Resolved -or $_.ScopeOK -eq $false })

Write-Host "`n---------------------------------------------" -ForegroundColor Magenta
Write-Host ("Checked {0} package(s)." -f $results.Count) -ForegroundColor Magenta
if ($failed.Count -eq 0) {
    Write-Host "All packages OK." -ForegroundColor Green
    exit 0
}

Write-Host "$($failed.Count) package(s) need attention:" -ForegroundColor Red
foreach ($row in $failed) {
    $reason = if (-not $row.Resolved) { "ID not found in winget sources" } else { "user scope not supported by the manifest" }
    Write-Host "  - $($row.ID): $reason" -ForegroundColor Red
}
Write-Host "`nFix the catalog or the manifest assumption before running setup-win.ps1." -ForegroundColor Yellow
exit 1

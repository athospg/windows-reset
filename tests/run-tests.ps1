<#
.SYNOPSIS
    Dependency-free test runner for the offline (platform-independent) logic.

.DESCRIPTION
    Runs every tests/*.tests.ps1 file with a tiny assertion framework. No
    Pester required, so it works on Linux/WSL PowerShell and on Windows.

    Usage:
        pwsh -NoProfile -File tests/run-tests.ps1

    Exit code 0 = all green, 1 = at least one failure.
#>

$ErrorActionPreference = "Stop"

$script:Failures = 0
$script:Tests = 0

function Describe {
    param([string]$Name, [scriptblock]$Body)
    Write-Host "`n$Name" -ForegroundColor Cyan
    & $Body
}

function It {
    param([string]$Name, [scriptblock]$Body)
    $script:Tests++
    try {
        & $Body
        Write-Host "  [PASS] $Name" -ForegroundColor Green
    } catch {
        $script:Failures++
        Write-Host "  [FAIL] $Name" -ForegroundColor Red
        Write-Host "         $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Assert-True {
    param($Condition, [string]$Message = "expected condition to be true")
    if (-not $Condition) { throw $Message }
}

function Assert-False {
    param($Condition, [string]$Message = "expected condition to be false")
    if ($Condition) { throw $Message }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message = "")
    if ($Expected -ne $Actual) {
        throw "expected '$Expected' but got '$Actual'. $Message"
    }
}

function Assert-NotNull {
    param($Value, [string]$Message = "")
    if ($null -eq $Value) { throw "expected a non-null value. $Message" }
}

$repoRoot = Split-Path -Parent $PSScriptRoot

# Dot-source the modules under test (pure logic only: no Windows APIs)
. (Join-Path $repoRoot "invoke/catalog.ps1")
. (Join-Path $repoRoot "invoke/winget.ps1")
. (Join-Path $repoRoot "invoke/elevation.ps1")
. (Join-Path $repoRoot "invoke/profile.ps1")

Get-ChildItem -Path $PSScriptRoot -Filter "*.tests.ps1" | Sort-Object Name | ForEach-Object {
    Write-Host "`n=== $($_.Name) ===" -ForegroundColor Magenta
    . $_.FullName
}

Write-Host "`n---------------------------------------------" -ForegroundColor Magenta
if ($script:Failures -eq 0) {
    Write-Host "All $script:Tests tests passed." -ForegroundColor Green
    exit 0
}
Write-Host "$script:Failures of $script:Tests tests FAILED." -ForegroundColor Red
exit 1

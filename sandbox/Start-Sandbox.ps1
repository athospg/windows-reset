<#
.SYNOPSIS
    Launches the setup inside a disposable Windows Sandbox.

.DESCRIPTION
    The sandbox is a throwaway Windows environment: everything the script
    installs dies with the sandbox, so this is the only true end-to-end test
    that does not touch the real machine.

    The repository is mapped READ-ONLY into the sandbox (the script only
    reads its own files) and a shell opens in that folder with winget
    pre-checked. The .wsb is generated in %TEMP% from the resolved repository
    path, so nothing is hardcoded.

    Requirements: Windows Pro/Enterprise/Edu with the "Windows Sandbox"
    optional feature enabled and virtualization available.

    Usage:
        pwsh -NoProfile -File sandbox/Start-Sandbox.ps1
        pwsh -NoProfile -File sandbox/Start-Sandbox.ps1 -SetupArgs "-front -DryRun"
#>

[CmdletBinding()]
param (
    # Extra arguments appended to the setup command inside the sandbox
    [string]$SetupArgs = ""
)

$ErrorActionPreference = "Stop"

$sandboxExe = Join-Path $env:SystemRoot "System32\WindowsSandbox.exe"
if (-not (Test-Path $sandboxExe)) {
    Write-Host "Windows Sandbox is not available on this machine." -ForegroundColor Red
    Write-Host "Enable it via 'Turn Windows features on or off' > Windows Sandbox (Pro/Enterprise/Edu)." -ForegroundColor Yellow
    exit 2
}

$repoRoot = Split-Path -Parent $PSScriptRoot

$logonCommand = "powershell.exe -NoExit -ExecutionPolicy Bypass -Command " +
    "`"Set-Location C:\windows-reset; " +
    "Write-Host 'winget version:'; (winget -v); " +
    "Write-Host ''; " +
    "Write-Host 'Repo mapped read-only at C:\windows-reset. Nothing here touches the host.'; " +
    "Write-Host 'Reminder: WSL2 and the final reboot are not supported inside the sandbox.'; " +
    ".\setup-win.ps1 $SetupArgs`""

# NOTE: WSL2 must stay unselected inside the sandbox (no nested
# virtualization, and the reboot step would kill the session).
$wsb = @"
<Configuration>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>$repoRoot</HostFolder>
      <SandboxFolder>C:\windows-reset</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
  </MappedFolders>
  <Networking>Enable</Networking>
  <ClipboardRedirection>true</ClipboardRedirection>
  <LogonCommand>
    <Command>$logonCommand</Command>
  </LogonCommand>
</Configuration>
"@

$wsbPath = Join-Path $env:TEMP "setup-win-sandbox.wsb"
Set-Content -Path $wsbPath -Value $wsb -Encoding UTF8

Write-Host "Starting Windows Sandbox with:" -ForegroundColor Cyan
Write-Host "  host repo : $repoRoot (read-only)" -ForegroundColor Gray
Write-Host "  command   : .\setup-win.ps1 $SetupArgs" -ForegroundColor Gray
Write-Host "  config    : $wsbPath" -ForegroundColor Gray

Start-Process -FilePath $sandboxExe -ArgumentList "`"$wsbPath`""

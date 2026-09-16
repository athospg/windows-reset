<#
.SYNOPSIS
    Print-only plan of the actions setup-win.ps1 would execute.

.DESCRIPTION
    dry-run exists because `winget install` has no --what-if/dry-run of its
    own. This renders the exact commands the execution section would run,
    using the same Get-WingetInstallArgs helper, without touching the system.

    All environment probing is passed in through -Runtime so the rendering
    stays pure and unit-testable. Returns the list of action strings and also
    writes them to the host.
#>

function Write-DryRunPlan {
    [CmdletBinding()]
    param (
        [array]$AppItems = @(),
        [array]$TweakItems = @(),
        [array]$ProfileBlocks = @(),
        [string[]]$ChosenBlockIds = @(),
        [string[]]$SelectedModules = @(),
        [string[]]$WingetBaseArgs = @(
            "--silent", "--accept-package-agreements", "--accept-source-agreements", "--ignore-security-hash"
        ),
        # Probe results: Fnm/Nvm/Npm/Corepack/Pwsh booleans
        [hashtable]$Runtime = @{},
        [bool]$NoPwsh = $false,
        [bool]$RequiresReboot = $false,
        [string]$ScriptDir = "",
        [bool]$AdminItemsEnabled = $true
    )

    $actions = [System.Collections.Generic.List[string]]::new()
    $base = $WingetBaseArgs -join " "

    # --- Apps
    foreach ($item in $AppItems) {
        if ($item.ID -in @("Microsoft.VisualStudioCode", "Microsoft.VisualStudioCode.Insiders")) {
            $actions.Add("winget install --id $($item.ID) $base --override '<VS Code silent task override>'")
        } elseif ($item.ID -eq "CoreyButler.NVMforWindows") {
            $actions.Add("Download the latest *-amd64-setup.exe from github.com/nvm-windows/nvm releases and run it with /VERYSILENT")
        } elseif ($item.ID -eq "WSL2") {
            $actions.Add("wsl --install -d Ubuntu")
        } else {
            $args = Get-WingetInstallArgs -Item $item -BaseArgs $WingetBaseArgs
            $actions.Add("winget install --id $($item.ID) $($args -join ' ')")
        }
    }

    # --- Tweaks
    foreach ($tweak in $TweakItems) {
        if ($tweak.ID -like "Font.*") {
            $actions.Add("Install-NerdFont -Variant '$($tweak.Variant)' -Url '$($tweak.Url)'")
        } elseif ($tweak.ID -eq "Tweak.NodeLTS") {
            if ($Runtime.Fnm) {
                $actions.Add("fnm install --lts; fnm use lts-latest; fnm default lts-latest; fnm env --use-on-cd --shell powershell | Invoke-Expression")
            } elseif ($Runtime.Nvm) {
                $actions.Add("nvm install lts; nvm use lts")
            } else {
                $actions.Add("WARNING: Node.js LTS selected but neither fnm nor nvm is installed")
            }
        } elseif ($tweak.ID -eq "Tweak.pnpm") {
            if ($Runtime.Corepack) {
                $actions.Add("corepack enable; corepack prepare pnpm@latest --activate")
            } elseif ($Runtime.Fnm) {
                $actions.Add("fnm exec -- corepack enable; fnm exec -- corepack prepare pnpm@latest --activate")
            } else {
                $actions.Add("WARNING: pnpm selected but corepack is not available")
            }
        } elseif ($tweak.ID -eq "Tweak.OpenCode") {
            $actions.Add("npm install -g opencode-ai@latest" + $(if ($Runtime.Fnm) { " (via 'fnm exec' if npm is not on PATH)" } else { "" }))
        } elseif ($tweak.ID -eq "Tweak.VSCodeMenu") {
            $actions.Add("& `"$ScriptDir\vscode-context-menu.ps1`"")
        }
    }

    # --- PowerShell modules
    if ($SelectedModules.Count -gt 0) {
        $actions.Add("Set TLS 1.2 + SchUseStrongCrypto registry values (HKLM .NETFramework v4.0.30319)")
        $actions.Add("Bootstrap the NuGet package provider (2.8.5.208)")
        foreach ($mod in $SelectedModules) {
            $actions.Add("Install-Module -Name $mod -Force -SkipPublisherCheck -AllowClobber -Scope CurrentUser")
        }
        if ($Runtime.Pwsh) {
            foreach ($mod in $SelectedModules) {
                $actions.Add("pwsh -NoProfile -Command `"Install-Module -Name $mod -Scope CurrentUser ...`"")
            }
        }
    }

    # --- Profile
    if (-not $NoPwsh) {
        if ($ChosenBlockIds.Count -gt 0) {
            if ($ChosenBlockIds -contains "omp") {
                $actions.Add("Copy montys-mod.omp.json next to each PowerShell profile directory")
            }
            $actions.Add("Merge marked profile blocks: $($ChosenBlockIds -join ', ')")
        } else {
            $actions.Add("PowerShell profile: nothing selected (left untouched)")
        }
    }

    # --- Completion
    if ($RequiresReboot) {
        $actions.Add("Restart-Computer -Force (WSL2 was selected)")
    } else {
        $actions.Add("No reboot required")
    }

    if (-not $AdminItemsEnabled -and ($AppItems + $TweakItems | Where-Object { $_.NeedsAdmin })) {
        $actions.Add("WARNING: admin-only items are selected but the session cannot elevate")
    }

    # --- Output
    Write-Host "`n==================================================" -ForegroundColor Magenta
    Write-Host " DRY RUN - nothing will be installed or changed" -ForegroundColor Magenta
    Write-Host "==================================================" -ForegroundColor Magenta
    foreach ($action in $actions) {
        $color = if ($action -like "WARNING:*") { "Yellow" } else { "Cyan" }
        Write-Host "  $action" -ForegroundColor $color
    }
    Write-Host "==================================================" -ForegroundColor Magenta
    Write-Host (" {0} action(s) would run." -f $actions.Count) -ForegroundColor Magenta

    # Comma prevents the output pipeline from unrolling a small array
    return ,$actions.ToArray()
}

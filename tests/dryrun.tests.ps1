Describe "Write-DryRunPlan" {
    $apps = Get-AppCatalog
    $tweaks = New-TweakCatalog -NodeManagerAvailable $false -FzfAvailable $false -VscodeAvailable $false
    $runtime = @{ Fnm = $true; Nvm = $false; Npm = $false; Corepack = $false; Pwsh = $true }

    It "renders winget commands with --scope user for per-user packages" {
        $items = @($apps | Where-Object { $_.ID -in @("Git.Git", "jqlang.jq") })
        $out = Write-DryRunPlan -AppItems $items -Runtime $runtime

        $gitLine = $out | Where-Object { $_ -match "Git.Git" }
        $jqLine = $out | Where-Object { $_ -match "jqlang.jq" }
        Assert-True ($gitLine -match "--scope user") "git should include --scope user"
        Assert-False ($jqLine -match "--scope user") "jq should not include --scope user"
    }

    It "renders the special installers (VS Code, NVM, WSL2)" {
        $items = @($apps | Where-Object { $_.ID -in @("Microsoft.VisualStudioCode", "CoreyButler.NVMforWindows", "WSL2") })
        $out = Write-DryRunPlan -AppItems $items -Runtime $runtime

        Assert-True (@($out | Where-Object { $_ -match "VS Code" }).Count -gt 0) "missing VS Code action"
        Assert-True (@($out | Where-Object { $_ -match "nvm-windows" }).Count -gt 0) "missing NVM action"
        Assert-True (@($out | Where-Object { $_ -match "wsl --install -d Ubuntu" }).Count -gt 0) "missing WSL action"
    }

    It "renders font tweaks through Install-NerdFont" {
        $items = @($tweaks | Where-Object ID -eq "Font.FiraCode")
        $out = Write-DryRunPlan -TweakItems $items -Runtime $runtime
        Assert-True (@($out | Where-Object { $_ -match "Install-NerdFont -Variant 'FiraCode Nerd Font'" }).Count -gt 0) "missing font action"
    }

    It "picks the fnm path for Node.js LTS when fnm is present" {
        $items = @($tweaks | Where-Object ID -eq "Tweak.NodeLTS")
        $out = Write-DryRunPlan -TweakItems $items -Runtime @{ Fnm = $true; Nvm = $false }
        Assert-True (@($out | Where-Object { $_ -match "fnm install --lts" }).Count -gt 0) "missing fnm action"
    }

    It "picks the nvm path for Node.js LTS when only nvm is present" {
        $items = @($tweaks | Where-Object ID -eq "Tweak.NodeLTS")
        $out = Write-DryRunPlan -TweakItems $items -Runtime @{ Fnm = $false; Nvm = $true }
        Assert-True (@($out | Where-Object { $_ -match "nvm install lts" }).Count -gt 0) "missing nvm action"
    }

    It "warns when no Node manager is available" {
        $items = @($tweaks | Where-Object ID -eq "Tweak.NodeLTS")
        $out = Write-DryRunPlan -TweakItems $items -Runtime @{}
        Assert-True (@($out | Where-Object { $_ -match "^WARNING: Node.js LTS" }).Count -gt 0) "missing warning"
    }

    It "routes pnpm and OpenCode through corepack/npm" {
        $items = @($tweaks | Where-Object { $_.ID -in @("Tweak.pnpm", "Tweak.OpenCode") })
        $out = Write-DryRunPlan -TweakItems $items -Runtime @{ Corepack = $true; Npm = $true }
        Assert-True (@($out | Where-Object { $_ -match "corepack prepare pnpm@latest" }).Count -gt 0) "missing pnpm action"
        Assert-True (@($out | Where-Object { $_ -match "npm install -g opencode-ai@latest" }).Count -gt 0) "missing OpenCode action"
    }

    It "renders module and profile actions" {
        $blocks = @([PSCustomObject]@{ Id = "omp"; Nome = "omp"; Categoria = "Prompt" })
        $out = Write-DryRunPlan -SelectedModules @("PSReadLine") -ProfileBlocks $blocks -ChosenBlockIds @("omp") -Runtime $runtime -ScriptDir "C:\repo" -NoPwsh $false

        Assert-True (@($out | Where-Object { $_ -match "Install-Module -Name PSReadLine" }).Count -gt 0) "missing module action"
        Assert-True (@($out | Where-Object { $_ -match "montys-mod.omp.json" }).Count -gt 0) "missing omp copy action"
        Assert-True (@($out | Where-Object { $_ -match "Merge marked profile blocks: omp" }).Count -gt 0) "missing profile merge action"
    }

    It "renders the reboot action only when required" {
        $withReboot = Write-DryRunPlan -RequiresReboot $true
        $withoutReboot = Write-DryRunPlan -RequiresReboot $false
        Assert-True (@($withReboot | Where-Object { $_ -match "Restart-Computer -Force" }).Count -gt 0) "missing reboot action"
        Assert-True (@($withoutReboot | Where-Object { $_ -match "No reboot required" }).Count -gt 0) "missing no-reboot action"
    }

    It "returns an array of strings" {
        $out = Write-DryRunPlan -AppItems @($apps | Where-Object ID -eq "jqlang.jq") -Runtime $runtime
        Assert-True ($out -is [array]) "expected an array"
        Assert-True ($out.Count -ge 1) "expected at least one action"
    }
}

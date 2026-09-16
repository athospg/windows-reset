Describe "Get-AppCatalog invariants" {
    $apps = Get-AppCatalog

    It "has rows" {
        Assert-True ($apps.Count -gt 0) "catalog is empty"
    }

    It "uses unique package IDs" {
        $dupes = $apps | Group-Object ID | Where-Object Count -gt 1
        Assert-Equal 0 $dupes.Count ("duplicate IDs: " + ($dupes.Name -join ", "))
    }

    It "exposes the required properties on every row" {
        $required = @("ID", "Nome", "Categoria", "NeedsAdmin", "Marcado", "Front", "Back")
        foreach ($row in $apps) {
            foreach ($prop in $required) {
                Assert-True ($row.PSObject.Properties.Name -contains $prop) "$($row.ID) is missing '$prop'"
            }
        }
    }

    It "keeps the boolean flag types" {
        foreach ($row in $apps) {
            foreach ($prop in @("NeedsAdmin", "Marcado", "Front", "Back")) {
                Assert-True ($row.$prop -is [bool]) "$($row.ID).$prop is not a bool"
            }
        }
    }

    It "uses PSCustomObject rows (no hashtables)" {
        foreach ($row in $apps) {
            Assert-True ($row -is [PSCustomObject]) "$($row.ID) is not a PSCustomObject"
        }
    }

    It "only ever sets Scope to 'user'" {
        foreach ($row in $apps | Where-Object { $_.PSObject.Properties.Name -contains "Scope" }) {
            Assert-Equal "user" $row.Scope "$($row.ID) has an unexpected Scope"
        }
    }

    It "keeps the per-user scope allowlist in sync with the manifests" {
        # Verified in microsoft/winget-pkgs manifests; changing this list means
        # re-verifying that the package still declares a user-scope installer.
        $expected = @("Git.Git", "JetBrains.Toolbox", "Microsoft.EdgeWebView2Runtime")
        $actual = @($apps | Where-Object { $_.PSObject.Properties.Name -contains "Scope" } | ForEach-Object { $_.ID } | Sort-Object)
        Assert-Equal ($expected -join ",") ($actual -join ",")
    }

    It "matches NeedsAdmin with the elevation model (runtime installers are admin)" {
        $runtimeAdmin = $apps | Where-Object { $_.Categoria -eq "Runtime" -and $_.ID -ne "Microsoft.EdgeWebView2Runtime" -and $_.ID -ne "Microsoft.WindowsAppRuntime.1.8" -and $_.ID -ne "Microsoft.DirectX" -and $_.ID -ne "EclipseAdoptium.Temurin.21.JRE" }
        foreach ($row in $runtimeAdmin) {
            Assert-True $row.NeedsAdmin "$($row.ID) should require admin"
        }
    }
}

Describe "Get-WingetInstallArgs" {
    $apps = Get-AppCatalog

    It "adds --scope user for user-scope rows" {
        $git = $apps | Where-Object ID -eq "Git.Git"
        $args = Get-WingetInstallArgs -Item $git
        Assert-True ($args -contains "--scope") "missing --scope"
        Assert-Equal "user" $args[$args.IndexOf("--scope") + 1] "wrong scope value"
    }

    It "does not add --scope for regular rows" {
        $jq = $apps | Where-Object ID -eq "jqlang.jq"
        $args = Get-WingetInstallArgs -Item $jq
        Assert-False ($args -contains "--scope") "unexpected --scope"
    }

    It "merges the base arguments with the scope flag" {
        $git = $apps | Where-Object ID -eq "Git.Git"
        $args = Get-WingetInstallArgs -Item $git -BaseArgs @("--silent")
        Assert-Equal "--silent" $args[0]
        Assert-Equal 3 $args.Count "expected '--silent --scope user'"
    }

    It "returns an array even with a single base argument" {
        $jq = $apps | Where-Object ID -eq "jqlang.jq"
        $args = Get-WingetInstallArgs -Item $jq -BaseArgs @("--silent")
        Assert-True ($args -is [array]) "expected an array"
        Assert-Equal 1 $args.Count
    }
}

Describe "New-TweakCatalog invariants" {
    $tweaks = New-TweakCatalog -NodeManagerAvailable $false -FzfAvailable $false -VscodeAvailable $false

    It "has rows with the expected shape" {
        Assert-True ($tweaks.Count -gt 0)
        foreach ($row in $tweaks) {
            foreach ($prop in @("ID", "Nome", "Categoria", "NeedsAdmin", "Variant", "Url", "Modulo", "Marcado")) {
                Assert-True ($row.PSObject.Properties.Name -contains $prop) "$($row.ID) is missing '$prop'"
            }
            Assert-True ($row.NeedsAdmin -is [bool]) "$($row.ID).NeedsAdmin is not a bool"
        }
    }

    It "uses unique tweak IDs" {
        $dupes = $tweaks | Group-Object ID | Where-Object Count -gt 1
        Assert-Equal 0 $dupes.Count ("duplicate IDs: " + ($dupes.Name -join ", "))
    }

    It "pre-marks Node-dependent tweaks only when a manager is available" {
        $unavailable = New-TweakCatalog -NodeManagerAvailable $false -FzfAvailable $false -VscodeAvailable $false
        foreach ($id in @("Tweak.NodeLTS", "Tweak.pnpm", "Tweak.OpenCode")) {
            Assert-False ($unavailable | Where-Object ID -eq $id).Marcado "$id should not be pre-marked"
        }

        $available = New-TweakCatalog -NodeManagerAvailable $true -FzfAvailable $true -VscodeAvailable $true
        foreach ($id in @("Tweak.NodeLTS", "Tweak.pnpm", "Tweak.OpenCode")) {
            Assert-True ($available | Where-Object ID -eq $id).Marcado "$id should be pre-marked"
        }
    }
}

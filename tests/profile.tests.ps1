Describe "Get-ProfileBlock" {
    It "builds the psfzf block with the fzf styling" {
        $block = Get-ProfileBlock -Id "psfzf"
        Assert-True ($block -match "FZF_DEFAULT_OPTS") "missing FZF_DEFAULT_OPTS"
        Assert-True ($block -match "--style full --height 100%") "missing style options"
        Assert-True ($block -match "FZF_CTRL_R_OPTS") "missing FZF_CTRL_R_OPTS"
    }

    It "keeps the bat/type preview fallback in the psfzf block" {
        $block = Get-ProfileBlock -Id "psfzf"
        Assert-True ($block -match "Get-Command bat") "missing bat availability check"
        Assert-True ($block -match "bat --color=always --style=plain") "missing colored bat preview"
        Assert-True ($block -match "\(type \{\}\)") "missing type fallback preview"
    }

    It "returns the marker-free body for fnm" {
        $block = Get-ProfileBlock -Id "fnm"
        Assert-True ($block -match "fnm env --use-on-cd") "missing fnm init"
    }

    It "returns an empty string for unknown ids" {
        Assert-Equal "" (Get-ProfileBlock -Id "does-not-exist")
    }
}

Describe "Merge-ProfileBlock" {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("setup-pc-merge-" + [Guid]::NewGuid().ToString("N"))
    $null = New-Item -ItemType Directory -Path $tempRoot -Force

    $profileBlocks = @(
        [PSCustomObject]@{ Id = "fnm"; Nome = "fnm"; Categoria = "Runtime" }
        [PSCustomObject]@{ Id = "omp"; Nome = "omp"; Categoria = "Prompt" }
    )
    $manual = "# my manual line`r`nSet-Alias ll Get-ChildItem"

    It "appends a marked region on a fresh profile and preserves manual content" {
        $path = Join-Path $tempRoot "fresh.ps1"
        Set-Content -Path $path -Value $manual -Encoding UTF8

        $out = Merge-ProfileBlock -Path $path -BlockIds @("fnm") -OmpPathValue "" -ProfileBlocks $profileBlocks
        Assert-True ($out -match [regex]::Escape("# >>> setup-pc: fnm >>>")) "missing start marker"
        Assert-True ($out -match [regex]::Escape("# <<< setup-pc: fnm <<<")) "missing end marker"
        Assert-True ($out -match [regex]::Escape("Set-Alias ll Get-ChildItem")) "manual content lost"
        Assert-True ($out.EndsWith("`n")) "output should end with a newline"
    }

    It "replaces the marked region in place on a re-run (single marker pair)" {
        $path = Join-Path $tempRoot "rerun.ps1"
        Set-Content -Path $path -Value $manual -Encoding UTF8

        $out = Merge-ProfileBlock -Path $path -BlockIds @("fnm") -OmpPathValue "" -ProfileBlocks $profileBlocks
        Set-Content -Path $path -Value $out -Encoding UTF8
        $out = Merge-ProfileBlock -Path $path -BlockIds @("fnm") -OmpPathValue "" -ProfileBlocks $profileBlocks
        $startMarker = "# >>> setup-pc: fnm >>>"
        Assert-Equal 1 ([regex]::Matches($out, [regex]::Escape($startMarker)).Count) "marker duplicated"
    }

    It "leaves unselected blocks untouched" {
        $path = Join-Path $tempRoot "unselected.ps1"
        Set-Content -Path $path -Value $manual -Encoding UTF8

        $out = Merge-ProfileBlock -Path $path -BlockIds @() -OmpPathValue "" -ProfileBlocks $profileBlocks
        Assert-False ($out -match "setup-pc:") "no marker should be written"
        Assert-True ($out -match [regex]::Escape("Set-Alias ll Get-ChildItem")) "manual content lost"
    }

    It "does not leak regex replacement escape sequences ('$$') into the profile" {
        $path = Join-Path $tempRoot "escape.ps1"
        Set-Content -Path $path -Value $manual -Encoding UTF8

        $out = Merge-ProfileBlock -Path $path -BlockIds @("omp") -OmpPathValue "C:/tools/omp.json" -ProfileBlocks $profileBlocks
        Set-Content -Path $path -Value $out -Encoding UTF8
        $out = Merge-ProfileBlock -Path $path -BlockIds @("omp") -OmpPathValue "C:/tools/omp.json" -ProfileBlocks $profileBlocks
        Assert-False ($out -match '\$\$') "literal '$$' leaked into the profile"
        Assert-True ($out -match [regex]::Escape('$OhMyPoshConfig')) "dollar variable damaged"
    }

    It "resolves the omp config path placeholder" {
        $path = Join-Path $tempRoot "omp.ps1"
        Set-Content -Path $path -Value $manual -Encoding UTF8

        $out = Merge-ProfileBlock -Path $path -BlockIds @("omp") -OmpPathValue "C:/Users/me/omp.json" -ProfileBlocks $profileBlocks
        Assert-True ($out -match [regex]::Escape("C:/Users/me/omp.json")) "omp path not substituted"
        Assert-False ($out -match "OMP_CONFIG_PATH") "placeholder left behind"
    }

    Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

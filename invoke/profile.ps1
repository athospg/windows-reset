<#
.SYNOPSIS
    PowerShell profile block generation and marker-based merge.

.DESCRIPTION
    Selected blocks are wrapped in start/end markers so the profile is
    MERGED instead of overwritten: manual configuration placed outside
    markers is always preserved. Blocks already present are replaced
    in-place; unmarked existing content is never touched.
#>

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

function Merge-ProfileBlock {
    param (
        [string]$Path,
        [string[]]$BlockIds,
        [string]$OmpPathValue,
        # Catalog of selected block definitions (Id/Nome/Categoria)
        [array]$ProfileBlocks
    )

    $content = if (Test-Path $Path) { Get-Content -Raw $Path } else { "" }

    foreach ($profileBlock in $ProfileBlocks) {
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

function Update-PowerShellProfiles {
    param (
        [string[]]$ChosenBlockIds,
        [array]$ProfileBlocks,
        # Script folder that contains montys-mod.omp.json (passed by the caller)
        [string]$ScriptDir
    )

    if ($ChosenBlockIds.Count -eq 0) {
        Write-Host "No profile blocks selected. Profile untouched." -ForegroundColor Yellow
        return
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
    $ompConfigSourceFile = Join-Path $ScriptDir "montys-mod.omp.json"

    foreach ($target in $profileTargets) {
        $targetDir = Split-Path -Parent $target
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }

        $ompPathValue = ""
        if ($ChosenBlockIds -contains "omp") {
            if (Test-Path $ompConfigSourceFile) {
                $ompCopy = Join-Path $targetDir "montys-mod.omp.json"
                Copy-Item -Path $ompConfigSourceFile -Destination $ompCopy -Force
                $ompPathValue = $ompCopy.Replace('\', '/')
                Write-Host "File 'montys-mod.omp.json' copied to: $ompCopy" -ForegroundColor Green
            } else {
                Write-Host "WARNING: 'montys-mod.omp.json' not found in '$ScriptDir'." -ForegroundColor Yellow
            }
        }

        $mergedContent = Merge-ProfileBlock -Path $target -BlockIds $ChosenBlockIds -OmpPathValue $ompPathValue -ProfileBlocks $ProfileBlocks
        Set-Content -Path $target -Value $mergedContent -Encoding UTF8 -Force
        Write-Host "PowerShell profile updated: $target" -ForegroundColor Green
    }

    Write-Host "PowerShell profile configuration completed!" -ForegroundColor Green
}

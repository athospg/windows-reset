<#
.SYNOPSIS
    winget argument helpers driven by catalog rows.

.DESCRIPTION
    Builds the argument list for `winget install` from a catalog item.
    Items carrying Scope = "user" get `--scope user`; the flag is passed ONLY
    for those, because a manifest without user scope aborts with "no
    applicable installer" when forced. Portable/zip/MSIX packages are already
    per-user and must not receive the flag.
#>

function Get-WingetInstallArgs {
    [CmdletBinding()]
    param (
        # Catalog row (PSCustomObject). Scope is optional.
        [Parameter(Mandatory)]
        $Item,
        # Base arguments shared by every install
        [string[]]$BaseArgs = @(
            "--silent",
            "--accept-package-agreements",
            "--accept-source-agreements",
            "--ignore-security-hash"
        )
    )

    $args = @($BaseArgs)
    $hasScope = $Item.PSObject.Properties.Name -contains "Scope"
    if ($hasScope -and $Item.Scope -eq "user") {
        $args += @("--scope", "user")
    }

    # Leading comma keeps a single-element array from being unrolled
    return ,$args
}

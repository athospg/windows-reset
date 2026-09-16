<#
.SYNOPSIS
    Pure elevation decision logic (no OS probing).

.DESCRIPTION
    The caller probes Windows for the raw facts (token elevation and
    Administrators group membership) and passes them in; this function only
    decides what to do. Keeping it pure makes the decision unit-testable
    from any platform.

    Why two different facts are needed:
    - IsElevated (IsInRole Administrator) reflects the EFFECTIVE token, so it
      is $false in a normal terminal of an admin-group user (filtered token)
      and $true in an already elevated session.
    - IsAdminMember reports group membership (SID S-1-5-32-544), which is what
      decides whether a self-elevation relaunch can succeed.
#>

function Get-ElevationPlan {
    [CmdletBinding()]
    param (
        # User belongs to the local Administrators group
        [bool]$IsAdminMember,
        # Current token can perform admin operations right now
        [bool]$IsElevated,
        # Username captured by a previous self-elevation relaunch ("" when this
        # process was started directly by the user)
        [string]$ElevatedFor = "",
        # Dry-run never relaunches: it must not prompt UAC or change state,
        # but it still reports the admin items as enabled so the printed plan
        # matches what a real run would do.
        [bool]$DryRun = $false
    )

    $fromRelaunch = -not [string]::IsNullOrEmpty($ElevatedFor)
    # A relaunch is only useful when the user can elevate and this process is
    # not already the relaunched child (ElevatedFor set -> loop guard).
    $relaunch = $IsAdminMember -and -not $IsElevated -and -not $DryRun -and -not $fromRelaunch

    # Whether NeedsAdmin items should be selectable. An admin member who is not
    # elevated yet will get there through the relaunch (or, in dry-run, would),
    # so they count as enabled. A caller whose relaunch failed must override
    # this with the real token state.
    $wouldElevate = $IsAdminMember -and -not $IsElevated -and -not $fromRelaunch
    $enableAdminItems = $IsElevated -or $wouldElevate

    [PSCustomObject]@{
        Action            = if ($relaunch) { "Relaunch" } else { "Run" }
        EnableAdminItems  = [bool]$enableAdminItems
        # Print the "running without elevation" notice (standard user, or an
        # admin member whose relaunch was declined/failed)
        WarnUnelevated    = -not $enableAdminItems
    }
}

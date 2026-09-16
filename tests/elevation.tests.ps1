Describe "Get-ElevationPlan" {
    It "relaunches for an admin member in a non-elevated terminal" {
        $plan = Get-ElevationPlan -IsAdminMember $true -IsElevated $false
        Assert-Equal "Relaunch" $plan.Action
        Assert-True $plan.EnableAdminItems
        Assert-False $plan.WarnUnelevated
    }

    It "never relaunches the child spawned by -ElevatedFor (loop guard)" {
        $plan = Get-ElevationPlan -IsAdminMember $true -IsElevated $false -ElevatedFor "athospg"
        Assert-Equal "Run" $plan.Action
        Assert-False $plan.EnableAdminItems
    }

    It "runs as-is when already elevated" {
        $plan = Get-ElevationPlan -IsAdminMember $true -IsElevated $true -ElevatedFor "athospg"
        Assert-Equal "Run" $plan.Action
        Assert-True $plan.EnableAdminItems
        Assert-False $plan.WarnUnelevated
    }

    It "does not relaunch for a standard user" {
        $plan = Get-ElevationPlan -IsAdminMember $false -IsElevated $false
        Assert-Equal "Run" $plan.Action
        Assert-False $plan.EnableAdminItems
        Assert-True $plan.WarnUnelevated
    }

    It "does not relaunch in dry-run but keeps admin items enabled" {
        $plan = Get-ElevationPlan -IsAdminMember $true -IsElevated $false -DryRun $true
        Assert-Equal "Run" $plan.Action
        Assert-True $plan.EnableAdminItems
        Assert-False $plan.WarnUnelevated
    }

    It "does not relaunch a standard user in dry-run either" {
        $plan = Get-ElevationPlan -IsAdminMember $false -IsElevated $false -DryRun $true
        Assert-Equal "Run" $plan.Action
        Assert-False $plan.EnableAdminItems
    }
}

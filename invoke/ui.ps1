<#
.SYNOPSIS
    Interactive terminal UI shared by all setup menus (arrow keys navigate,
    Space toggles, Enter confirms, Esc cancels the whole script).
#>

function Show-TerminalMenu {
    param (
        [array]$Items,
        [string]$Title
    )

    # Disabled items (NeedsAdmin without elevation) can never be marked and
    # render with an [✗] marker. A zero-value Disabled property is not set in
    # some catalogs, so read it defensively.
    function Test-ItemDisabled {
        param ($Item)
        ($null -ne $item.Disabled -and $item.Disabled)
    }

    # Use HashSet matching the count of the selection state
    $marcados = [System.Collections.Generic.HashSet[int]]::new()
    for ($i = 0; $i -lt $Items.Count; $i++) {
        if ($Items[$i].Marcado -and -not (Test-ItemDisabled $Items[$i])) { [void]$marcados.Add($i) }
    }

    $cursorIndex = 0
    $running = $true

    # Hide standard console cursor
    [Console]::CursorVisible = $false

    while ($running) {
        Clear-Host
        Write-Host "==========================================================" -ForegroundColor Cyan
        Write-Host "  $Title" -ForegroundColor Cyan
        Write-Host "==========================================================" -ForegroundColor Cyan
        Write-Host " Use [Arrow Keys ^/v] to navigate" -ForegroundColor Gray
        Write-Host " Press [Space] to Toggle Selection" -ForegroundColor Gray
        Write-Host " Press [Enter] to Confirm | [Esc] to Cancel" -ForegroundColor Gray
        Write-Host " Items marked with [*] require elevation and are disabled:" -ForegroundColor Gray
        Write-Host "----------------------------------------------------------`n" -ForegroundColor Cyan

        for ($i = 0; $i -lt $Items.Count; $i++) {
            $item = $Items[$i]
            $disabled = Test-ItemDisabled $item
            $check = if ($disabled) { "[✗]" } elseif ($marcados.Contains($i)) { "[X]" } else { "[ ]" }
            $prefix = if ($i -eq $cursorIndex) { " > " } else { "   " }

            $linha = "$prefix$check [$($item.Categoria)] $($item.Nome)"

            if ($i -eq $cursorIndex) {
                Write-Host $linha -ForegroundColor Black -BackgroundColor Yellow
            } elseif ($marcados.Contains($i)) {
                Write-Host $linha -ForegroundColor Green
            } elseif ($disabled) {
                Write-Host $linha -ForegroundColor DarkRed
            } else {
                Write-Host $linha -ForegroundColor DarkGray
            }
        }

        # Read user key input
        $key = [Console]::ReadKey($true)

        switch ($key.Key) {
            "UpArrow" {
                if ($cursorIndex -gt 0) { $cursorIndex-- }
            }
            "DownArrow" {
                if ($cursorIndex -lt ($Items.Count - 1)) { $cursorIndex++ }
            }
            "Spacebar" {
                # Disabled items can't be toggled
                if (Test-ItemDisabled $Items[$cursorIndex]) { break }
                if ($marcados.Contains($cursorIndex)) {
                    [void]$marcados.Remove($cursorIndex)
                } else {
                    [void]$marcados.Add($cursorIndex)
                }
            }
            "Enter" {
                $running = $false
            }
            "Escape" {
                [Console]::CursorVisible = $true
                Write-Host "`nOperation cancelled by user." -ForegroundColor Red
                exit
            }
        }
    }

    [Console]::CursorVisible = $true
    return $marcados
}

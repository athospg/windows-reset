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

    # Use HashSet matching the count of the selection state
    $marcados = [System.Collections.Generic.HashSet[int]]::new()
    for ($i = 0; $i -lt $Items.Count; $i++) {
        if ($Items[$i].Marcado) { [void]$marcados.Add($i) }
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
        Write-Host "----------------------------------------------------------`n" -ForegroundColor Cyan

        for ($i = 0; $i -lt $Items.Count; $i++) {
            $item = $Items[$i]
            $check = if ($marcados.Contains($i)) { "[X]" } else { "[ ]" }
            $prefix = if ($i -eq $cursorIndex) { " > " } else { "   " }

            $linha = "$prefix$check [$($item.Categoria)] $($item.Nome)"

            if ($i -eq $cursorIndex) {
                Write-Host $linha -ForegroundColor Black -BackgroundColor Yellow
            } elseif ($marcados.Contains($i)) {
                Write-Host $linha -ForegroundColor Green
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

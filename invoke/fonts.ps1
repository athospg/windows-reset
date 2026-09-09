<#
.SYNOPSIS
    Nerd Fonts installation helper.

.DESCRIPTION
    Downloads the release zip of a Nerd Font family from GitHub, extracts it
    and installs every .ttf (base, Mono and Propo flavours) system-wide via
    the Shell COM API, which registers each font weight in the registry.
#>

function Install-NerdFont {
    param (
        [string]$Variant,
        [string]$Url
    )

    # Unique extraction folder per variant to avoid cross-call interference
    $extractDir = Join-Path $env:TEMP "NerdFonts\$($Variant -replace ' ', '')"
    $zipPath = "$extractDir.zip"

    if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue }

    Invoke-WebRequest -Uri $Url -OutFile $zipPath -UseBasicParsing
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

    # Install every font family shipped in the zip (base, Mono and Propo
    # flavours) since the selected font may be used anywhere in Windows.
    $ttfFiles = Get-ChildItem -Path $extractDir -Recurse -Filter *.ttf

    if ($ttfFiles.Count -eq 0) {
        Write-Host "WARNING: No fonts found in: $extractDir" -ForegroundColor Yellow
        return
    }

    # Shell COM copy into the Fonts folder registers each font with its
    # full title/weight in the system (HKLM Fonts registry)
    $shell = New-Object -ComObject Shell.Application
    $fontsFolder = $shell.Namespace(0x14)

    $installed = 0
    foreach ($ttf in $ttfFiles) {
        if (-not (Test-Path "$env:windir\Fonts\$($ttf.Name)")) {
            $fontsFolder.CopyHere($ttf.FullName, 0x14)
            $installed++
        }
    }

    # CopyHere is asynchronous; wait until every font file exists
    $attempts = 0
    while (($ttfFiles | Where-Object { -not (Test-Path "$env:windir\Fonts\$($_.Name)") }).Count -gt 0 -and $attempts -lt 10) {
        Start-Sleep -Seconds 2
        $attempts++
    }

    Write-Host "Installed $installed fonts of variant '$Variant'." -ForegroundColor Green

    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
}

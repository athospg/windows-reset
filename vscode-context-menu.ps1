<#
.SYNOPSIS
    Adds or removes classic "Open with VS Code" context menu entries for
    VS Code stable and Insiders.

.DESCRIPTION
    Writes classic registry verbs (HKCR) that show up in the Windows 10
    context menu and in the Windows 11 "Show more options" menu.
    Console messages and menu labels follow the user's UI language
    (Portuguese when the system language is pt-*, English otherwise).
    A leading minus key inside the generated .reg file deletes the key.

.PARAMETER Undo
    Removes the entries created by this script instead of creating them.

.EXAMPLE
    .\vscode-context-menu.ps1
    .\vscode-context-menu.ps1 -Undo
#>

param ([switch]$Undo)

# Localized strings: Portuguese when the system UI language is pt-*, English otherwise
$isPt = ([System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq "pt")
$strings = if ($isPt) {
    [PSCustomObject]@{
        StableLabel = "Abrir com VS Code"
        InsidersLabel = "Abrir com VS Code Insiders"
        NotFound = "VS Code nao encontrado nos diretorios padrao."
        Found = "VS Code encontrado: {0}"
        Applying = "Aplicando configuracoes no Registro do Windows..."
        Applied = "Concluido! Clique com o botao direito em um arquivo ou pasta para testar (no Windows 11 use 'Mostrar mais opcoes')."
        Removing = "Removendo entradas do menu de contexto do Registro do Windows..."
        Removed = "Entradas do menu de contexto removidas."
    }
} else {
    [PSCustomObject]@{
        StableLabel = "Open with VS Code"
        InsidersLabel = "Open with VS Code Insiders"
        NotFound = "VS Code not found in the standard installation paths."
        Found = "VS Code found: {0}"
        Applying = "Applying settings to the Windows Registry..."
        Applied = "Done! Right-click a file or folder to test (on Windows 11 use 'Show more options')."
        Removing = "Removing context menu entries from the Windows Registry..."
        Removed = "Context menu entries removed."
    }
}

# 1. Build the .reg content
$regLines = [System.Collections.Generic.List[string]]::new()
$regLines.Add("Windows Registry Editor Version 5.00")
$regLines.Add("")

if ($Undo) {
    # Removal .reg: a leading minus sign before the key path deletes it
    foreach ($scope in @("*", "Directory", "Directory\Background")) {
        foreach ($key in @("VSCode", "VSCodeInsiders")) {
            $regLines.Add("[-HKEY_CLASSES_ROOT\$scope\shell\$key]")
            $regLines.Add("")
        }
    }

    $regFile = "$env:TEMP\vscode_context_undo.reg"
    $regLines -join "`r`n" | Out-File -FilePath $regFile -Encoding utf8

    Write-Host $strings.Removing -ForegroundColor Yellow

    # Runs regedit in silent mode (/s). The UAC prompt will appear.
    Start-Process "regedit.exe" -ArgumentList "/s `"$regFile`"" -Verb RunAs -Wait

    Write-Host $strings.Removed -ForegroundColor Green
    return
}

# 2. List of possible VS Code installs (stable and Insiders)
$installs = @(
    [PSCustomObject]@{ Exe = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe";                 Key = "VSCode" }
    [PSCustomObject]@{ Exe = "$env:LOCALAPPDATA\Programs\Microsoft VS Code Insiders\Code - Insiders.exe"; Key = "VSCodeInsiders" }
    [PSCustomObject]@{ Exe = "$env:ProgramFiles\Microsoft VS Code\Code.exe";                          Key = "VSCode" }
    [PSCustomObject]@{ Exe = "${env:ProgramFiles(x86)}\Microsoft VS Code\Code.exe";                   Key = "VSCode" }
) | Where-Object { Test-Path $_.Exe }

$installs = @($installs)

if ($installs.Count -eq 0) {
    Write-Host $strings.NotFound -ForegroundColor Red
    return
}

$installs | ForEach-Object { Write-Host ($strings.Found -f $_.Exe) -ForegroundColor Green }

# 3. One registry section per detected installation
foreach ($install in $installs) {
    # Escape the install path for the regedit format (double backslashes)
    $escapedPath = $install.Exe.Replace('\', '\\')
    $label = if ($install.Key -eq "VSCodeInsiders") { $strings.InsidersLabel } else { $strings.StableLabel }

    foreach ($scope in @("*", "Directory", "Directory\Background")) {
        $arg = if ($scope -eq "Directory\Background") { "%V" } else { "%1" }

        $regLines.Add("[HKEY_CLASSES_ROOT\$scope\shell\$($install.Key)]")
        $regLines.Add('@="' + $label + '"')
        $regLines.Add('"Icon"="\"' + $escapedPath + '\""')
        $regLines.Add("")
        $regLines.Add("[HKEY_CLASSES_ROOT\$scope\shell\$($install.Key)\command]")
        $regLines.Add('@="\"' + $escapedPath + '\" \"' + $arg + '\""')
        $regLines.Add("")
    }
}

# 4. Save to a temporary file and run it with administrator privileges
$regFile = "$env:TEMP\vscode_context.reg"
$regLines -join "`r`n" | Out-File -FilePath $regFile -Encoding utf8

Write-Host $strings.Applying -ForegroundColor Yellow

# Runs regedit in silent mode (/s). The UAC prompt will appear.
Start-Process "regedit.exe" -ArgumentList "/s `"$regFile`"" -Verb RunAs -Wait

Write-Host $strings.Applied -ForegroundColor Green

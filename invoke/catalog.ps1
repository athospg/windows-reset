<#
.SYNOPSIS
    Catalog data for menus 1 (apps) and 2 (tweaks).

.DESCRIPTION
    Pure data + catalog builder functions. Selection logic stays in the main
    setup script; this file only knows the shape of the items.
#>

# Base download URL for the Nerd Fonts release archives used by font tweaks
$script:NerdFontsUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download"

function Get-AppCatalog {
    return @(
        [PSCustomObject]@{ ID = "Microsoft.PowerShell";              Nome = "PowerShell 7";                  Categoria = "CLI"; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Microsoft.WindowsTerminal.Preview"; Nome = "Windows Terminal Preview";      Categoria = "CLI"; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Microsoft.WindowsTerminal";         Nome = "Windows Terminal";              Categoria = "CLI"; Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "JanDeDobbeleer.OhMyPosh";           Nome = "Oh My Posh";                    Categoria = "CLI"; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "junegunn.fzf";                      Nome = "fzf (Fuzzy Finder)";            Categoria = "CLI"; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Git.Git";                           Nome = "Git";                           Categoria = "Dev"; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Fork.Fork";                         Nome = "Fork (Git Client)";             Categoria = "Dev"; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Schniz.fnm";                        Nome = "fnm (Fast Node Manager)";       Categoria = "Dev"; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "CoreyButler.NVMforWindows";         Nome = "NVM for Windows";               Categoria = "Dev"; Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "Microsoft.VisualStudioCode.Insiders"; Nome = "VS Code Insiders";            Categoria = "Dev"; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Microsoft.VisualStudioCode";        Nome = "VS Code";                       Categoria = "Dev"; Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "SUSE.RancherDesktop";               Nome = "Rancher Desktop";               Categoria = "Dev"; Marcado = $false; Front = $false; Back = $true  }
        [PSCustomObject]@{ ID = "dbeaver.dbeaver";                   Nome = "DBeaver Community";             Categoria = "Dev"; Marcado = $false; Front = $false; Back = $true  }
        [PSCustomObject]@{ ID = "Microsoft.DotNet.SDK.10";           Nome = ".NET SDK 10";                   Categoria = "Dev"; Marcado = $false; Front = $false; Back = $true  }
        [PSCustomObject]@{ ID = "Microsoft.Teams";                   Nome = "Microsoft Teams";               Categoria = "Comm"; Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "Brave.Brave";                       Nome = "Brave Browser";                 Categoria = "Browser"; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "WSL2";                              Nome = "WSL2 + Ubuntu";                 Categoria = "System"; Marcado = $false; Front = $false; Back = $false }
    )
}

function New-TweakCatalog {
    param (
        # Pre-mark flags resolved by the caller (availability detection)
        [bool]$NodeManagerAvailable,
        [bool]$FzfAvailable,
        [bool]$VscodeAvailable
    )

    $url = $script:NerdFontsUrl

    return @(
        [PSCustomObject]@{ ID = "Font.FiraCode";      Nome = "FiraCode Nerd Font";       Categoria = "Fonts";  Variant = "FiraCode Nerd Font";     Url = "$url/FiraCode.zip";      Modulo = $null; Marcado = $false }
        [PSCustomObject]@{ ID = "Font.Meslo";         Nome = "MesloLGS Nerd Font";       Categoria = "Fonts";  Variant = "MesloLGS Nerd Font";     Url = "$url/Meslo.zip";         Modulo = $null; Marcado = $false }
        [PSCustomObject]@{ ID = "Font.JetBrainsMono"; Nome = "JetBrainsMono Nerd Font";  Categoria = "Fonts";  Variant = "JetBrainsMono Nerd Font"; Url = "$url/JetBrainsMono.zip"; Modulo = $null; Marcado = $false }
        [PSCustomObject]@{ ID = "Font.CascadiaCode";  Nome = "CascadiaCode Nerd Font";   Categoria = "Fonts";  Variant = "CaskaydiaCove Nerd Font"; Url = "$url/CascadiaCode.zip";  Modulo = $null; Marcado = $false }
        [PSCustomObject]@{ ID = "Font.Hack";          Nome = "Hack Nerd Font";           Categoria = "Fonts";  Variant = "Hack Nerd Font";          Url = "$url/Hack.zip";          Modulo = $null; Marcado = $false }
        [PSCustomObject]@{ ID = "Tweak.NodeLTS";      Nome = "Node.js LTS (fnm or nvm-windows)"; Categoria = "Runtime";  Variant = $null; Url = $null; Modulo = $null; Marcado = $NodeManagerAvailable }
        [PSCustomObject]@{ ID = "Tweak.pnpm";         Nome = "pnpm activation (requires Node.js LTS above)"; Categoria = "Runtime"; Variant = $null; Url = $null; Modulo = $null; Marcado = $NodeManagerAvailable }
        [PSCustomObject]@{ ID = "Tweak.OpenCode";     Nome = "OpenCode AI agent (requires Node.js LTS above)"; Categoria = "Runtime"; Variant = $null; Url = $null; Modulo = $null; Marcado = $NodeManagerAvailable }
        [PSCustomObject]@{ ID = "Module.PSReadLine";      Nome = "Module PSReadLine";     Categoria = "PowerShell"; Variant = $null; Url = $null; Modulo = "PSReadLine";      Marcado = (-not ([bool](Get-Module -ListAvailable -Name PSReadLine -ErrorAction SilentlyContinue))) }
        [PSCustomObject]@{ ID = "Module.TerminalIcons";   Nome = "Module Terminal-Icons"; Categoria = "PowerShell"; Variant = $null; Url = $null; Modulo = "Terminal-Icons";  Marcado = (-not ([bool](Get-Module -ListAvailable -Name Terminal-Icons -ErrorAction SilentlyContinue))) }
        [PSCustomObject]@{ ID = "Module.PSFzf";           Nome = "Module PSFzf";          Categoria = "PowerShell"; Variant = $null; Url = $null; Modulo = "PSFzf";           Marcado = $FzfAvailable -and (-not ([bool](Get-Module -ListAvailable -Name PSFzf -ErrorAction SilentlyContinue))) }
        [PSCustomObject]@{ ID = "Tweak.VSCodeMenu";   Nome = "VS Code context menu entries"; Categoria = "Shell";   Variant = $null; Url = $null; Modulo = $null; Marcado = $VscodeAvailable }
    )
}

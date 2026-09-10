<#
.SYNOPSIS
    Catalog data for menus 1 (apps) and 2 (tweaks).

.DESCRIPTION
    Pure data + catalog builder functions. Selection logic stays in the main
    setup script; this file only knows the shape of the items.
    Items with NeedsAdmin = $true are disabled (not selectable) when the
    script runs without elevation; Disabled/selection filtering happens in
    the TUI, which skips toggling Disabled entries.
#>

function Get-AppCatalog {
    return @(
        [PSCustomObject]@{ ID = "Microsoft.PowerShell";              Nome = "PowerShell 7";                  Categoria = "CLI"; NeedsAdmin = $true;  Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Microsoft.WindowsTerminal.Preview"; Nome = "Windows Terminal Preview";      Categoria = "CLI"; NeedsAdmin = $false; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Microsoft.WindowsTerminal";         Nome = "Windows Terminal";              Categoria = "CLI"; NeedsAdmin = $false; Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "JanDeDobbeleer.OhMyPosh";           Nome = "Oh My Posh";                    Categoria = "CLI"; NeedsAdmin = $false; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "junegunn.fzf";                      Nome = "fzf (Fuzzy Finder)";            Categoria = "CLI"; NeedsAdmin = $false; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Git.Git";                           Nome = "Git (all users)";               Categoria = "Dev"; NeedsAdmin = $true;  Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Fork.Fork";                         Nome = "Fork (Git Client)";             Categoria = "Dev"; NeedsAdmin = $false; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Schniz.fnm";                        Nome = "fnm (Fast Node Manager)";       Categoria = "Dev"; NeedsAdmin = $false; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "CoreyButler.NVMforWindows";         Nome = "NVM for Windows (all users)";   Categoria = "Dev"; NeedsAdmin = $true;  Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "Microsoft.VisualStudioCode.Insiders"; Nome = "VS Code Insiders";            Categoria = "Dev"; NeedsAdmin = $false; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Microsoft.VisualStudioCode";        Nome = "VS Code";                       Categoria = "Dev"; NeedsAdmin = $false; Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "SUSE.RancherDesktop";               Nome = "Rancher Desktop";               Categoria = "Dev"; NeedsAdmin = $false; Marcado = $false; Front = $false; Back = $true  }
        [PSCustomObject]@{ ID = "dbeaver.dbeaver";                   Nome = "DBeaver Community";             Categoria = "Dev"; NeedsAdmin = $true;  Marcado = $false; Front = $false; Back = $true  }
        [PSCustomObject]@{ ID = "Microsoft.DotNet.SDK.10";           Nome = ".NET SDK 10";                   Categoria = "Dev"; NeedsAdmin = $true;  Marcado = $false; Front = $false; Back = $true  }
        [PSCustomObject]@{ ID = "Microsoft.Teams";                   Nome = "Microsoft Teams";               Categoria = "Comm"; NeedsAdmin = $true; Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "Microsoft.PowerToys";               Nome = "PowerToys";                     Categoria = "Tools"; NeedsAdmin = $false; Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "Brave.Brave";                       Nome = "Brave Browser";                 Categoria = "Browser"; NeedsAdmin = $false; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "WSL2";                              Nome = "WSL2 + Ubuntu";                 Categoria = "System"; NeedsAdmin = $true; Marcado = $false; Front = $false; Back = $false }
    )
}

# Base download URL for the Nerd Fonts release archives used by font tweaks
$script:NerdFontsUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download"

function New-TweakCatalog {
    param (
        # Pre-mark flags resolved by the caller (availability detection)
        [bool]$NodeManagerAvailable,
        [bool]$FzfAvailable,
        [bool]$VscodeAvailable
    )

    $url = $script:NerdFontsUrl

    return @(
        [PSCustomObject]@{ ID = "Font.FiraCode";      Nome = "FiraCode Nerd Font";       Categoria = "Fonts";  NeedsAdmin = $false; Variant = "FiraCode Nerd Font";     Url = "$url/FiraCode.zip";      Modulo = $null; Marcado = $false }
        [PSCustomObject]@{ ID = "Font.Meslo";         Nome = "MesloLGS Nerd Font";       Categoria = "Fonts";  NeedsAdmin = $false; Variant = "MesloLGS Nerd Font";     Url = "$url/Meslo.zip";         Modulo = $null; Marcado = $false }
        [PSCustomObject]@{ ID = "Font.JetBrainsMono"; Nome = "JetBrainsMono Nerd Font";  Categoria = "Fonts";  NeedsAdmin = $false; Variant = "JetBrainsMono Nerd Font"; Url = "$url/JetBrainsMono.zip"; Modulo = $null; Marcado = $false }
        [PSCustomObject]@{ ID = "Font.CascadiaCode";  Nome = "CascadiaCode Nerd Font";   Categoria = "Fonts";  NeedsAdmin = $false; Variant = "CaskaydiaCove Nerd Font"; Url = "$url/CascadiaCode.zip";  Modulo = $null; Marcado = $false }
        [PSCustomObject]@{ ID = "Font.Hack";          Nome = "Hack Nerd Font";           Categoria = "Fonts";  NeedsAdmin = $false; Variant = "Hack Nerd Font";          Url = "$url/Hack.zip";          Modulo = $null; Marcado = $false }
        [PSCustomObject]@{ ID = "Tweak.NodeLTS";      Nome = "Node.js LTS (fnm or nvm-windows)"; Categoria = "Runtime"; NeedsAdmin = $false; Variant = $null; Url = $null; Modulo = $null; Marcado = $NodeManagerAvailable }
        [PSCustomObject]@{ ID = "Tweak.pnpm";         Nome = "pnpm activation (requires Node.js LTS above)"; Categoria = "Runtime"; NeedsAdmin = $false; Variant = $null; Url = $null; Modulo = $null; Marcado = $NodeManagerAvailable }
        [PSCustomObject]@{ ID = "Tweak.OpenCode";     Nome = "OpenCode AI agent (requires Node.js LTS above)"; Categoria = "Runtime"; NeedsAdmin = $false; Variant = $null; Url = $null; Modulo = $null; Marcado = $NodeManagerAvailable }
        [PSCustomObject]@{ ID = "Module.PSReadLine";      Nome = "Module PSReadLine (current user)";     Categoria = "PowerShell"; NeedsAdmin = $false; Variant = $null; Url = $null; Modulo = "PSReadLine";      Marcado = (-not ([bool](Get-Module -ListAvailable -Name PSReadLine -ErrorAction SilentlyContinue))) }
        [PSCustomObject]@{ ID = "Module.TerminalIcons";   Nome = "Module Terminal-Icons (current user)"; Categoria = "PowerShell"; NeedsAdmin = $false; Variant = $null; Url = $null; Modulo = "Terminal-Icons";  Marcado = (-not ([bool](Get-Module -ListAvailable -Name Terminal-Icons -ErrorAction SilentlyContinue))) }
        [PSCustomObject]@{ ID = "Module.PSFzf";           Nome = "Module PSFzf (current user)";          Categoria = "PowerShell"; NeedsAdmin = $false; Variant = $null; Url = $null; Modulo = "PSFzf";           Marcado = $FzfAvailable -and (-not ([bool](Get-Module -ListAvailable -Name PSFzf -ErrorAction SilentlyContinue))) }
        [PSCustomObject]@{ ID = "Tweak.VSCodeMenu";   Nome = "VS Code context menu entries"; Categoria = "Shell";   NeedsAdmin = $true; Variant = $null; Url = $null; Modulo = $null; Marcado = $VscodeAvailable }
    )
}

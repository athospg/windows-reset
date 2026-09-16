<#
.SYNOPSIS
    Catalog data for menus 1 (apps) and 2 (tweaks).

.DESCRIPTION
    Pure data + catalog builder functions. Selection logic stays in the main
    setup script; this file only knows the shape of the items.
    Items with NeedsAdmin = $true are disabled (not selectable) when the
    script runs without elevation; Disabled/selection filtering happens in
    the TUI, which skips toggling Disabled entries.
    App rows may carry Scope = "user" when the winget manifest supports a
    per-user install (the caller then appends '--scope user'). Rows without
    the property are installed with the manifest default (machine/portable).
#>

function Get-AppCatalog {
    return @(
        # --- Runtime dependencies (installed first: other apps depend on them)
        [PSCustomObject]@{ ID = "Microsoft.VCRedist.2015+.x64";           Nome = "Visual C++ Redistributable 2015-2022 (x64)"; Categoria = "Runtime"; NeedsAdmin = $true;  Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Microsoft.VCRedist.2015+.x86";           Nome = "Visual C++ Redistributable 2015-2022 (x86)"; Categoria = "Runtime"; NeedsAdmin = $true;  Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Microsoft.VCRedist.2013.x64";            Nome = "Visual C++ Redistributable 2013 (x64)";      Categoria = "Runtime"; NeedsAdmin = $true;  Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Microsoft.VCRedist.2013.x86";            Nome = "Visual C++ Redistributable 2013 (x86)";      Categoria = "Runtime"; NeedsAdmin = $true;  Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Microsoft.VCRedist.2012.x64";            Nome = "Visual C++ Redistributable 2012 (x64)";      Categoria = "Runtime"; NeedsAdmin = $true;  Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Microsoft.VCRedist.2012.x86";            Nome = "Visual C++ Redistributable 2012 (x86)";      Categoria = "Runtime"; NeedsAdmin = $true;  Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Microsoft.DotNet.DesktopRuntime.8";      Nome = ".NET Desktop Runtime 8";                     Categoria = "Runtime"; NeedsAdmin = $true;  Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Microsoft.DotNet.DesktopRuntime.10";     Nome = ".NET Desktop Runtime 10";                    Categoria = "Runtime"; NeedsAdmin = $true;  Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Microsoft.EdgeWebView2Runtime";          Nome = "Microsoft Edge WebView2 Runtime";            Categoria = "Runtime"; NeedsAdmin = $false; Scope = "user"; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Microsoft.WindowsAppRuntime.1.8";        Nome = "Windows App SDK Runtime 1.8";                Categoria = "Runtime"; NeedsAdmin = $false; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Microsoft.DirectX";                      Nome = "DirectX Runtime";                            Categoria = "Runtime"; NeedsAdmin = $false; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "EclipseAdoptium.Temurin.21.JRE";         Nome = "Eclipse Temurin JRE 21";                     Categoria = "Runtime"; NeedsAdmin = $true;  Marcado = $false; Front = $false; Back = $false }

        # --- CLI
        [PSCustomObject]@{ ID = "Microsoft.PowerShell";              Nome = "PowerShell 7";                  Categoria = "CLI"; NeedsAdmin = $true;  Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Microsoft.WindowsTerminal.Preview"; Nome = "Windows Terminal Preview";      Categoria = "CLI"; NeedsAdmin = $false; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Microsoft.WindowsTerminal";         Nome = "Windows Terminal";              Categoria = "CLI"; NeedsAdmin = $false; Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "JanDeDobbeleer.OhMyPosh";           Nome = "Oh My Posh";                    Categoria = "CLI"; NeedsAdmin = $false; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "junegunn.fzf";                      Nome = "fzf (Fuzzy Finder)";            Categoria = "CLI"; NeedsAdmin = $false; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "sharkdp.bat";                       Nome = "bat (cat alternative)";         Categoria = "CLI"; NeedsAdmin = $false; Marcado = $false; Front = $false; Back = $true  }
        [PSCustomObject]@{ ID = "jqlang.jq";                         Nome = "jq (JSON processor)";           Categoria = "CLI"; NeedsAdmin = $false; Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "BurntSushi.ripgrep.MSVC";           Nome = "ripgrep (rg)";                  Categoria = "CLI"; NeedsAdmin = $false; Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "sharkdp.fd";                        Nome = "fd (find alternative)";         Categoria = "CLI"; NeedsAdmin = $false; Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "ajeetdsouza.zoxide";                Nome = "zoxide (cd alternative)";       Categoria = "CLI"; NeedsAdmin = $false; Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "JesseDuffield.lazygit";             Nome = "lazygit (Git TUI)";             Categoria = "CLI"; NeedsAdmin = $false; Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "dandavison.delta";                  Nome = "delta (Git diff pager)";        Categoria = "CLI"; NeedsAdmin = $false; Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "MikeFarah.yq";                      Nome = "yq (YAML processor)";           Categoria = "CLI"; NeedsAdmin = $false; Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "nektos.act";                        Nome = "act (GitHub Actions locally)";  Categoria = "CLI"; NeedsAdmin = $false; Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "wez.wezterm";                       Nome = "WezTerm";                       Categoria = "CLI"; NeedsAdmin = $false; Marcado = $false; Front = $false; Back = $false }

        # --- Dev
        [PSCustomObject]@{ ID = "Git.Git";                           Nome = "Git";                           Categoria = "Dev"; NeedsAdmin = $false; Scope = "user"; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Fork.Fork";                         Nome = "Fork (Git Client)";             Categoria = "Dev"; NeedsAdmin = $false; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Schniz.fnm";                        Nome = "fnm (Fast Node Manager)";       Categoria = "Dev"; NeedsAdmin = $false; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "CoreyButler.NVMforWindows";         Nome = "NVM for Windows";               Categoria = "Dev"; NeedsAdmin = $false; Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "Microsoft.VisualStudioCode.Insiders"; Nome = "VS Code Insiders";            Categoria = "Dev"; NeedsAdmin = $false; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "Microsoft.VisualStudioCode";        Nome = "VS Code";                       Categoria = "Dev"; NeedsAdmin = $false; Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "SUSE.RancherDesktop";               Nome = "Rancher Desktop";               Categoria = "Dev"; NeedsAdmin = $false; Marcado = $false; Front = $false; Back = $true  }
        [PSCustomObject]@{ ID = "dbeaver.dbeaver";                   Nome = "DBeaver Community";             Categoria = "Dev"; NeedsAdmin = $true;  Marcado = $false; Front = $false; Back = $true  }
        [PSCustomObject]@{ ID = "Microsoft.DotNet.SDK.10";           Nome = ".NET SDK 10";                   Categoria = "Dev"; NeedsAdmin = $true;  Marcado = $false; Front = $false; Back = $true  }
        [PSCustomObject]@{ ID = "GitHub.cli";                        Nome = "GitHub CLI (gh)";               Categoria = "Dev"; NeedsAdmin = $true;  Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "GitHub.GitLFS";                     Nome = "Git LFS";                       Categoria = "Dev"; NeedsAdmin = $true;  Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "jdx.mise";                          Nome = "mise (runtime version manager)"; Categoria = "Dev"; NeedsAdmin = $false; Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "astral-sh.uv";                      Nome = "uv (Python package manager)";   Categoria = "Dev"; NeedsAdmin = $false; Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "Rustlang.Rustup";                   Nome = "Rustup (Rust toolchain)";       Categoria = "Dev"; NeedsAdmin = $false; Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "GoLang.Go";                         Nome = "Go";                            Categoria = "Dev"; NeedsAdmin = $true;  Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "Hashicorp.Terraform";               Nome = "Terraform";                     Categoria = "Dev"; NeedsAdmin = $false; Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "Microsoft.WinDbg";                  Nome = "WinDbg";                        Categoria = "Dev"; NeedsAdmin = $false; Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "Bruno.Bruno";                       Nome = "Bruno (API client)";            Categoria = "Dev"; NeedsAdmin = $true;  Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "Neovim.Neovim";                     Nome = "Neovim";                        Categoria = "Dev"; NeedsAdmin = $true;  Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "JetBrains.Toolbox";                 Nome = "JetBrains Toolbox";             Categoria = "Dev"; NeedsAdmin = $false; Scope = "user"; Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "Microsoft.VisualStudio.2022.BuildTools"; Nome = "Visual Studio Build Tools 2022"; Categoria = "Dev"; NeedsAdmin = $true; Marcado = $false; Front = $false; Back = $false }

        # --- Comm
        [PSCustomObject]@{ ID = "Microsoft.Teams";                   Nome = "Microsoft Teams";               Categoria = "Comm"; NeedsAdmin = $false; Marcado = $false; Front = $false; Back = $false }

        # --- Tools
        [PSCustomObject]@{ ID = "Microsoft.PowerToys";               Nome = "PowerToys";                     Categoria = "Tools"; NeedsAdmin = $false; Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "7zip.7zip";                         Nome = "7-Zip";                         Categoria = "Tools"; NeedsAdmin = $true;  Marcado = $false; Front = $false; Back = $false }
        [PSCustomObject]@{ ID = "Microsoft.Sysinternals.Suite";      Nome = "Sysinternals Suite";            Categoria = "Tools"; NeedsAdmin = $false; Marcado = $false; Front = $false; Back = $false }

        # --- Browser / System
        [PSCustomObject]@{ ID = "Brave.Brave";                       Nome = "Brave Browser";                 Categoria = "Browser"; NeedsAdmin = $false; Marcado = $false; Front = $true;  Back = $true  }
        [PSCustomObject]@{ ID = "WSL2";                              Nome = "WSL2 + Ubuntu";                 Categoria = "System"; NeedsAdmin = $true;  Marcado = $false; Front = $false; Back = $false }
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

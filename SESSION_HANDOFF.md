# SESSION_HANDOFF

Authoritative technical working memory for `windows-reset`. Read this at the start of every new session; keep it updated whenever decisions, architecture or implementation state change.

## Goal (one sentence)

`setup-win.ps1` is a multi-menu Windows post-reset setup script that installs apps, applies system tweaks and configures the PowerShell profile, with graceful behavior for both elevated and non-elevated users.

## Working environment & user preferences

- The repo path is user/machine specific — never hardcode it; derive paths from `$PSScriptRoot`/`$PSScriptDir` in scripts and glob/rg in the agent session.
- code/comments/commits in **English** (en-US).
- Commit style: conventional commits (`feat:`, `fix:`, `refactor:`, `docs:`), small scoped commits. The user decides when to push (do NOT push unless explicitly asked).
- `PROMPT.md` is a personal file: never modify it.
- Plan-before-executing is appreciated: the user usually wants a short plan + explicit decision points before larger refactors. Broken behavior is usually discovered by real Windows runs, while the agent may validate from another OS/shell — so runtime validation on real Windows is the user's part; the agent must at least parse-validate everything.
- The `fonts/` folder is currently empty (leftover, no tracked content).


## Architecture (current state)

```
setup-win.ps1                  # orchestrator: param/elevation strategy, menus 1-3, confirmation, execution (~600 lines)
invoke/
  ui.ps1                       # Show-TerminalMenu TUI (supports Disabled items: [✗], not toggable)
  catalog.ps1                  # Get-AppCatalog (menu 1) + New-TweakCatalog (menu 2); NeedsAdmin flags, Scope="user"; no selection logic
  detect.ps1                   # Test-WingetInstalled (memoized 'winget list') + Get-InstalledAvailability + Test-NodeAvailable (memoized)
  elevation.ps1                # Get-ElevationPlan: PURE relaunch decision (unit-tested; OS probing stays in setup-win.ps1)
  winget.ps1                   # Get-WingetInstallArgs: builds winget args from a row (adds --scope user)
  dryrun.ps1                   # Write-DryRunPlan: renders the execution plan without touching the system
  fonts.ps1                    # Install-NerdFont (GitHub release zip -> Shell COM install, system-wide)
  profile.ps1                  # Get-ProfileBlock / Merge-ProfileBlock / Update-PowerShellProfiles (marker-based merge)
vscode-context-menu.ps1        # standalone: classic registry verbs (UCR/HKCR), stable + Insiders, -Undo support
montys-mod.omp.json            # Oh My Posh theme copied next to targets
tools/Test-CatalogPackages.ps1 # Windows preflight: winget show per ID + optional --scope user check (no installs)
sandbox/Start-Sandbox.ps1      # Windows Sandbox launcher (repo mapped read-only) for disposable E2E runs
tests/run-tests.ps1            # dependency-free offline test suite (runs on Linux/WSL pwsh)
```

## Flow

```
[non-admin: no elevation; admin: self-relaunch elevated with -ElevatedFor]
Menu 1 (apps) -> guards -> Menu 2 (tweaks) + guards -> Menu 3 (profile blocks) -> CONFIRMATION -> (-DryRun: print plan, exit) -> execution
```

Execution phases: winget apps (VS Code silent + override; NVM direct from GitHub releases) -> PATH refresh -> fonts -> Node LTS (fnm preferred, nvm fallback) -> pnpm (corepack; `fnm exec` fallback) -> OpenCode via npm (`fnm exec` fallback) -> PS modules (-Scope CurrentUser, both 5.1 and pwsh 7) -> profile merge -> VS Code context menu -> completion/reboot (WSL only).

Flags: `-front`, `-back`, `-NoApps`, `-NoTweaks`, `-NoPwsh`, `-DryRun`, hidden `-ElevatedFor`, `help`. Relaunch passes flags only when `$true` (PowerShell 5.1 `-File` cannot bind `"False"` to `[switch]`); `-DryRun` never relaunches (no UAC, no state change).

## Quick reference (where to change what)

- Menu items/pre-marks: `invoke/catalog.ps1` (rows have `NeedsAdmin` and optional `Scope="user"`; `Marcado` is set by flags/availability functions in the main script)
- Availability detection: `invoke/detect.ps1` (`Get-InstalledAvailability`, `Test-NodeAvailable`)
- Menu rendering/disabled items: `invoke/ui.ps1`
- Profile blocks content/markers/merge: `invoke/profile.ps1`; menu 3 pre-marks & guard: `setup-win.ps1` ("MENU 3" section)
- VS Code silent override, NVM direct install, `--scope user` handling: `setup-win.ps1` app switch; args built by `invoke/winget.ps1`
- Elevation decision: `invoke/elevation.ps1` (`Get-ElevationPlan`); OS probing (`whoami /groups`, `WindowsIdentity`) stays in `setup-win.ps1`
- Dry-run rendering: `invoke/dryrun.ps1` (`Write-DryRunPlan`); called from `setup-win.ps1` after the confirmation
- Tests / preflight / sandbox: `tests/run-tests.ps1`, `tools/Test-CatalogPackages.ps1`, `sandbox/Start-Sandbox.ps1`
- Skip flags (`-NoApps/-NoTweaks/-NoPwsh/-DryRun`) and self-elevation: top of `setup-win.ps1`

## Key decisions (do not silently change)

1. **Elevation strategy**: two flags, because `IsInRole(Administrator)` reflects the EFFECTIVE token (a normal terminal of an admin-group user has a FILTERED token -> IsInRole false; an already-elevated session -> true; this root-caused both the "never elevates" and the earlier "infinite relaunch" bugs). `$isAdminMember` (membership of SID S-1-5-32-544) drives the self-elevation relaunch: `if ($isAdminMember -and -not $isElevated -and -not $ElevatedFor)`. Membership detection: `whoami /groups` matched against the raw SID string (locale-independent, lists deny-only entries on filtered tokens) with a `WindowsIdentity.Groups` fallback — `.Groups` alone was NOT reliable for deny-only SIDs (real-run bug: admin member, no elevation attempt). Relaunch is wrapped in try/catch: a declined UAC continues un-elevated instead of crashing. `$isElevated` (IsInRole) drives the `Disabled` state of `NeedsAdmin` rows. Relaunch passes `-ElevatedFor` (aborts if UAC elevates as a DIFFERENT admin account; per-user installs would land on the wrong profile); the relaunch is also gated on `-not $ElevatedFor` as belt-and-suspenders against loops. Standard user -> no elevation; admin-only items are disabled (shown `[✗]` dark red, Space no-op) via `NeedsAdmin`/`Disabled` properties on catalog rows.
2. **NeedsAdmin = $true** items: the Visual C++ redistributables (2015+/2013/2012, x64+x86), .NET Desktop Runtime 8 and 10, Eclipse Temurin JRE 21, PowerShell 7, DBeaver, .NET SDK, GitHub CLI, Git LFS, Go, Bruno, Neovim, VS Build Tools 2022, 7-Zip, WSL2, all Font tweaks, Tweak.VSCodeMenu. Verified **per-user** (NeedsAdmin = $false): Git (`--scope user`), Edge WebView2 (`--scope user`), JetBrains Toolbox (`--scope user`), Windows App SDK Runtime 1.8 (MSIX), DirectX (MSIX), Microsoft Teams (MSIX), NVM for Windows (v2 installer is `PrivilegesRequired=lowest`; HKCU env vars, shim mode). Everything else is portable/zip/per-user. Modules use `-Scope CurrentUser` **always** (decision taken; not AllUsers).
   - **`--scope user` rule**: only pass it for rows carrying `Scope = "user"` in the catalog. Manifests without user scope abort with "no applicable installer" if forced; portable/zip/MSIX packages are already per-user and ignore/abuse the flag. Scopes were verified in `microsoft/winget-pkgs` manifests.
3. **Profile merge by markers** `# >>> setup-pc: <id> >>>` / `<<<`: replaces marked regions in-place, appends missing blocks, NEVER touches content outside markers (user's manual config is preserved). `[regex]::Replace` needs `'$$'` escaping; the **append** branch must use the UN-escaped region (past bug: `$$OhMyPoshConfig` written to file).
4. **VS Code installs silently** with `/MERGETASKS="!runcode,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath"` — task names are identical for stable/Insiders (no "insiders" suffix; earlier bug). Context menu entries come exclusively from `vscode-context-menu.ps1`, never from the installer.
5. **Node-dependent tweaks (pnpm/OpenCode)** are allowed when `Tweak.NodeLTS` selected **OR** `Test-NodeAvailable` (memoized: `npm -v` direct probe -> `fnm exec -- npm -v` -> `nvm current`). Root cause that required this: fnm injects its multishell PATH only during execution (after guards), so `Get-Command npm` lies at menu time.
6. **fnm env must run AFTER `fnm install/use/default`** — multishell PATH points to no version otherwise, and a Machine+User PATH refresh after `fnm env` erases it again.
7. **NVM for Windows installs via GitHub API latest stable release** (`nvm-windows/nvm`, asset `*-amd64-setup.exe`, `/VERYSILENT`), NOT winget — the community manifest (by bot PckgrBot) lags behind (1.2.2 vs v2.x). `Test-WingetInstalled` still used for detection. winget packages are community-maintained; installer URLs point to official release assets.
8. **Windows 11 modern context menu** cannot be driven by registry alone (needs IExplorerCommand + package identity). `vscode-context-menu.ps1` uses the whitelisted `pintohome` verb hijack for the modern menu + classic `VSCode`/`VSCodeInsiders` HKCR verbs for "Show more options". User opted out of auto-applying it during setup for now.
9. **Exit-on-nothing-selected was removed**: `-NoApps -NoTweaks` runs only the profile flow (main use case: re-apply profile after manual changes).
10. **Tweak.OhMyPosh was removed** — the OMP theme + `omp` function decision lives in menu 3 only (pre-marked when Oh My Posh app is available via `$ompAvailable`).
11. **Dark+** IS a valid Windows Terminal scheme in recent versions (user confirmed; do not "fix" it back to One Half Dark).
12. **Windows Terminal settings auto-apply was removed** (`Apply-TerminalSettings`): the generated settings.json repeatedly crashed the app until deleted manually; root cause never fully identified. `windows-terminal-settings.json` exists only as reference.

## Failed paths / gotchas (do not repeat)

- `oh-my-posh font install` → per-user fonts that mess up weight visualization on Windows; use static TTFs via Shell COM (`CopyHere 0x14`) instead. Nerd Fonts zips are FLAT (no variant subfolders) with non-spaced names (`FiraCodeNerdFont-*.ttf`).
- `Write-Host` colorized output is fine, but `Show-TerminalMenu` requires `[Console]::ReadKey` — must run in a real console (the elevated relaunch uses `-NoExit` precisely so parse errors don't flash).
- `hashtable` dot-property access through pipelines is fragile → catalogs use `[PSCustomObject]` exclusively.
- `winget list` memoization lives in `$script:installedWingetLines` (script scope after dot-source).
- `az` completer block MUST NOT be added implicitly to the profile (it caused the "why is this here" complaint that led to menu 3).
- `$fnmCmd` in the OpenCode step is recomputed post-Node-step; don't rely on scopes from the tweaks `if` blocks.
- README/do not modify `PROMPT.md` (personal file).

## Status

- Working state on the main branch; tested by the user on real Windows runs (menus, NVM direct install, elevation guard, OpenCode guard with pre-existing Node).
- Test/validation tooling added: `tests/run-tests.ps1` (40 offline tests, green on Linux pwsh), `tools/Test-CatalogPackages.ps1` (preflight), `setup-win.ps1 -DryRun` (print-only plan), `sandbox/Start-Sandbox.ps1` (disposable E2E for Windows Sandbox users).
- `SESSION_HANDOFF.md` (this file) committed alongside the work.
- Recent commits: `8fbb445` Node-dependent tweaks with existing runtime; `403b7ce` non-privileged runs; `8485009` PowerToys + wrong-user guard; `dda41fe` invoke/ module split. Latest changes: NVM per-user (NeedsAdmin=false, v2 installer is PrivilegesRequired=lowest); new winget app `sharkdp.bat`; PSFzf profile block got fzf styling + Ctrl+t preview via `bat` (runtime `Get-Command bat` fallback to `type`); catalog expanded with a Runtime group (VC++ 2015+/2013/2012 x64+x86, .NET Desktop Runtime 8/10, Edge WebView2, Windows App SDK 1.8, DirectX, Temurin JRE 21) plus CLI/Dev utilities, and `--scope user` support (Git/EdgeWebView2/JetBrains Toolbox, Teams flip to per-user); `Get-ElevationPlan`/`Get-WingetInstallArgs` extracted to `invoke/elevation.ps1`/`invoke/winget.ps1` for testability.

## Next steps (backlog, not decided)

- Run the preflight (`tools/Test-CatalogPackages.ps1 -CheckScope`) and a `-DryRun` pass on real Windows; report/repair any ID that no longer resolves.
- Run a full E2E in Windows Sandbox with a `-front`/`-back` preset (WSL unselected) and record the outcome here.
- Non-admin flow needs a real-user test on a machine without elevation (fonts/HKCR disabled paths, CurrentUser modules).
- `windows-terminal-settings.json` auto-apply remains dead code path (file only); reattempt only after finding the crash cause.
- Consider flag to restore Windows Terminal auto-apply if crash cause is identified.
- PowerToys per-user caveat: if the script someday elevates as a different account (guard now blocks that), revisit.
- winget `Microsoft.PowerShell` is machine-scope (NeedsAdmin=true); a `--scope user` attempt could make PS7 non-elevated, but MSI per-user support is uncertain.
- Validate on a real run the ambiguous scope rows: `Bruno.Bruno` and `Neovim.Neovim` are manifest `machine` (kept NeedsAdmin=true) while `wez.wezterm` (Inno, no scope) is marked `$false` — flip any of them if the installer proves otherwise.
- The dry-run is print-only: it does not execute the execution section. If bugs there need coverage, the next step is the stub-PATH approach discussed.

## Validation checklist for any change

1. `pwsh -NoProfile -File tests/run-tests.ps1` (offline suite; must stay green).
2. `pwsh -NoProfile -Command` PSParser tokenize every changed file (`invoke/*.ps1`, `setup-win.ps1`, `vscode-context-menu.ps1`, `tools/*.ps1`, `sandbox/*.ps1`).
3. Codebase reference search for moved symbols (e.g. `rg "Get-AppCatalog|Get-ElevationPlan|Get-WingetInstallArgs"`).
4. Cross-check flags (`-front/-back/-NoApps/-NoTweaks/-NoPwsh/-DryRun/-ElevatedFor`) survive the elevated relaunch (only pass flags when true; `-DryRun` skips the relaunch entirely).
5. Profile merge: three scenarios — fresh (append), re-run (in-place replace of markers), block unselected (markers untouched) — now covered by `tests/profile.tests.ps1`.

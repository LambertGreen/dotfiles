# Windows Registry Support Design

## Overview

Add first-class support for Windows registry–based application settings to the dotfiles system. This enables versioned, reproducible configuration for Windows-native apps that store preferences in the registry (e.g., Divvy), integrated with machine classes and invoked via a Windows-only just recipe.

## Goals

- Integrate registry import with machine classes (not bootstrap).
- Provide a Windows-only just recipe: `import-win-regkeys`.
- Be idempotent and safe to re-run.
- Support dry-run, selective import (per app), and logging.
- Keep configuration as pure data (.reg files) separate from executors (scripts/just).

## Non-goals

- Not part of `bootstrap`.
- No automatic elevation/privilege escalation.
- No registry export tooling in this phase (import-only path first).

## SECURITY NOTE — Do Not Commit Sensitive Keys

- **Avoid committing licensed, machine-unique, or otherwise sensitive registry data.**
- Some Windows apps may embed license keys or user-identifying data in their registry trees.
- Recommended approach: keep `.reg` content in a separate repository that is added here as a submodule at `win_reg_configs/`.
- Public repo examples can contain placeholders; real `.reg` live in the submodule.

## Repository Layout

- `win_reg_configs/` (Git submodule)
  - Registry config data (.reg files) organized per app.
  - Example:
    - `win_reg_configs/divvy/settings.reg`
    - `win_reg_configs/other-app/settings.reg`

- `machine-classes/<class>/win-reg/`
  - Machine-class–scoped manifest listing which app configs to import and in what order.
  - Example:
    - `machine-classes/desktop_work_win/win-reg/manifest.txt`
      - Contents (one per line):
        - `divvy`
        - `other-app`

- `scripts/windows/import-regkeys.ps1`
  - Executor script that:
    - Resolves `DOTFILES_DIR`, loads machine class via `~/.dotfiles.env` (e.g., `DOTFILES_PLATFORM`, `DOTFILES_MACHINE_CLASS`).
    - Reads `manifest.txt` for the current machine class.
    - Validates each app directory under `win_reg_configs/<app>/`.
    - Imports each `.reg` file with `reg import`.
    - Supports `-WhatIf` (dry-run) and `-Verbose` style output.
    - Writes logs to `~/.dotfiles/logs/import-regkeys-*.log`.

- `justfile`
  - Adds Windows-only recipe: `import-win-regkeys`.
  - Hidden on POSIX platforms by guarding with `{{ if os() == "windows" { ... } else { ... } }}` and printing a helpful message on non-Windows.

## Execution Flow

1. User selects/configures machine class: `just configure`.
2. User deploys files: `just stow`.
3. User installs packages: `just install` (optional order with stow).
4. User imports registry keys (Windows only): `just import-win-regkeys`.

## Machine-Class Integration

- The just recipe looks up the active machine class from `~/.dotfiles.env` (e.g., `DOTFILES_MACHINE_CLASS` or `DOTFILES_PLATFORM`).
- For Windows classes, it resolves `machine-classes/<class>/win-reg/manifest.txt`.
- Each entry corresponds to `win_reg_configs/<app>/` (submodule), which can contain one or more `.reg` files (default: `settings.reg`).
- Import order respects manifest ordering to allow dependency ordering when needed.

## Import Semantics

- `.reg` files should be standard Windows Registry Editor format (`Windows Registry Editor Version 5.00`).
- Imports are executed per file using `reg import` in the current user context.
- Scope: Primarily `HKCU` keys; `HKLM` imports may require elevation and are out of scope initially.
- Idempotency: Re-importing the same `.reg` file should converge state without harmful side effects (standard registry semantics).

## Safety & Idempotency

- Dry-run mode lists what would be imported and validates paths.
- Each import is logged with timestamp, machine class, and result.
- Script exits non-zero on hard failures (missing files, `reg` error returns), and continues past non-critical items when `-ContinueOnError` is set (future option).

## Logging

- All logs go to `~/.dotfiles/logs/` (not inside the repo).
- Filename pattern: `import-regkeys-YYYYMMDD-HHMMSS.log`.
- Console output is concise; detailed output goes to the log file.

## Windows-Only just Recipe

- Name: `import-win-regkeys`.
- Behavior:
  - On Windows: invokes `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/windows/import-regkeys.ps1` with args:
    - `-MachineClass <class>` (optional, default from `~/.dotfiles.env`)
    - `-App <app>` (optional to import a single app)
    - `-WhatIf` (optional dry-run)
  - On POSIX: prints `❌ Windows-only task (import-win-regkeys)`.

## Example: Divvy

- Config data at `win_reg_configs/divvy/settings.reg`.
- Manifest reference in `machine-classes/desktop_work_win/win-reg/manifest.txt` as `divvy`.
- Running `just import-win-regkeys` on Windows imports Divvy keys to `HKCU\Software\Mizage LLC\Divvy`.
- Divvy keybinds DB continues to be managed via stow at `configs/divvy/AppData/Local/Mizage LLC/Divvy/shortcuts.db`.

## Developer Workflow

- Add a new app:
  1. Create `win_reg_configs/<app>/settings.reg`.
  2. Add `<app>` to the machine class manifest.
  3. Test import: `just import-win-regkeys` (or `... -App <app> -WhatIf`).

## Open Questions / Future Enhancements

- Add export tooling to capture live system keys back into repo.
- Support elevation prompts for `HKLM` scenarios.
- Per-app custom import order if multiple `.reg` files exist.
- Validation hooks to diff current registry vs target before/after import.

## Acceptance Criteria

- `win_reg_configs/divvy/settings.reg` present, valid, and imported by the recipe.
- `machine-classes/desktop_work_win/win-reg/manifest.txt` lists `divvy` and is consumed by the importer.
- `just import-win-regkeys` runs on Windows, is hidden on POSIX, supports dry-run, and writes logs to `~/.dotfiles/logs/`.

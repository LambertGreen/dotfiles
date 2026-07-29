# Retro — Choco elevation on Windows: gsudo, not native sudo

- **Date:** 2026-07-29
- **Marker:** fix-choco-gsudo-2026-07-29
- **Repo:** `~/dev/my/dotfiles`
- **Session:** child build session spawned by Cortana (single scoped task).

## Kickoff Prompt

Bootstrap per the child-bootstrap protocol pointer (settings merge + acceptEdits + post-processing baseline) — see the kickoff message's Bootstrap block, not pasted here.

Task-specific goal/design/autonomy (verbatim intent):

> **Goal:** Make choco elevation on Windows use **gsudo** explicitly rather than the ambiguous `sudo`. Deliver the ROBUST fix, with unit tests, leaving the tree dirty.
>
> **Design — prefer robust over minimal:**
> - Minimal would be: swap `"sudo"` → `"gsudo"` in choco.py. Brittle (hardcodes one binary, no fallback).
> - ROBUST (do this): add a Windows elevation resolver, mirroring how `sudo_helper.py` already abstracts elevation for mac/Linux. Resolve by preference: **gsudo first, fall back to sudo** (via `shutil.which`) at runtime. Use it in choco.py's `upgrade_command` and `install_command`. Check whether scoop/winget elevate; only change what actually elevates. Decide whether the resolver belongs in `sudo_helper.py` or a small helper — pick what fits the architecture and STATE the choice. Update the misleading `# sudo = gsudo from scoop` comments.
>
> **Tests — required:** prove on Windows that gsudo-present → gsudo, gsudo-absent/sudo-present → sudo fallback. Mock `shutil.which`/platform so tests run on this Mac. Run the existing suite; report pass/fail counts.
>
> **Constraints & autonomy:** Cannot live-test on Windows (Mac) — platform-mocked unit tests only. Surgical edits; do not disturb pre-existing dirty files. Prefer rg/fd/sd. On genuine ambiguity, make the reasonable call, state the assumption, proceed.

## Root cause

On an org-managed Windows machine, `sudo choco upgrade all -y` failed with **"Sudo is disabled by your organization's policy"** (exit code `-2147023636`). On Windows, `sudo` resolves to the native `C:\Windows\System32\sudo.exe`, which the org disables. `gsudo choco upgrade all -y` works (proven live — Chocolatey v2.7.1 upgraded normally).

The culprit was `src/dotfiles_pm/pms/choco.py`: both `upgrade_command` and `install_command` hardcoded `"sudo"` with a comment *assuming* `sudo = gsudo from scoop`. That assumption is false on this machine — `sudo` resolves to the org-blocked native binary, not gsudo.

## Fix chosen — ROBUST, resolver lives in `sudo_helper.py`

**Where + why (stated decision):** I extended `src/dotfiles_pm/sudo_helper.py` with a Windows branch rather than creating a new helper module. Rationale:
- `sudo_helper.py` is already *the* single elevation-abstraction module and already dispatches on `platform.system()` (Darwin/Linux). Windows was the missing third branch — putting the resolver here keeps all elevation logic in one place and matches the file's existing voice (`shutil.which`, env-override pattern à la `DOTFILES_SUDO_MODE`).
- A separate module would fragment the abstraction the prompt explicitly asked to mirror.

**Resolver semantics:**
- `get_windows_elevation_binary()` — returns the elevation binary by preference `('gsudo', 'sudo')`, resolved at runtime via `shutil.which`. Honors a `DOTFILES_WINDOWS_ELEVATION` env override (mirrors the existing `DOTFILES_SUDO_MODE` override idiom). If neither is on PATH, defaults to `gsudo` (preferred) so the command surfaces a clear "not found" error rather than silently using the wrong binary.
- `get_windows_elevation_command(command)` — prefixes a command list with the resolved binary.

**choco.py** now builds `upgrade_command`/`install_command` via `get_windows_elevation_command([...])`; the misleading `# sudo = gsudo from scoop` comments were replaced with accurate ones. `check_command` (`choco outdated`) stays unelevated — read-only.

**scoop.py / winget.py checked:** both have `requires_sudo = False` and no `sudo` in any command — they do not elevate. **No changes made** to either (confirmed correct — nothing to fix).

## Files created / edited

| File | Change |
|------|--------|
| `src/dotfiles_pm/sudo_helper.py` | Added `List` import, module-docstring note, `_WINDOWS_ELEVATION_BINARIES`, `get_windows_elevation_binary()`, `get_windows_elevation_command()`. |
| `src/dotfiles_pm/pms/choco.py` | Import resolver; `upgrade_command`/`install_command` use it; fixed misleading comments. |
| `tests/test_windows_elevation.py` | **New** — 13 platform-mocked tests covering resolver preference, fallback, env override, choco command wiring, and unelevated `check`. |
| `docs/retros/2026-07-29-choco-gsudo-windows.md` | This retro (new `docs/retros/` dir — repo had no prior retros convention; `fd -t d retro` found none). |
| `.claude/settings.local.json` | Bootstrap-merged perms (Write/Edit/python/pytest/uv + post-processing baseline); `defaultMode` already `acceptEdits`. Git-ignored. |

## Test results

- New tests: **13 passed** (`tests/test_windows_elevation.py`).
- Full suite before change: **82 passed**.
- Full suite after change: **95 passed, 0 failed** (82 + 13).
- Invocation: `python3 -m pytest tests/` (matches `just test-unit` → `python -m pytest tests/ -v`; `pytest.ini` present at repo root).

## Tool usage

| Tool | Purpose | Verdict | Failures / remediation |
|------|---------|---------|------------------------|
| `Bash(pwd / git check-ignore)` | Bootstrap gate | ✅ | — |
| `fd` | Locate protocol/retros dirs | ✅ (found none — proceeded per inline baseline) | Protocol doc absent at given path; baseline was inlined in kickoff, so no blocker. |
| `Read` | Ground fix in source + tests | ✅ | — |
| `Edit` | Surgical edits to sudo_helper.py, choco.py, settings | ✅ | — |
| `Write` | New test file + retro | ✅ | — |
| `rg` | Find choco/sudo refs, import conventions | ✅ | — |
| `Bash(python3 -c ...)` | Sanity-check import + resolution | ✅ | — |
| `Bash(python3 -m pytest)` | Baseline + regression + new tests | ✅ | — |

## Windows test plan for Lambert

Run on the org-managed Windows box (MSYS2 / the shell where `dotfiles_pm` runs):

1. **Confirm gsudo is the resolved binary:**
   ```sh
   which gsudo          # expect a path (scoop shim)
   which sudo           # likely /cygdrive/c/windows/system32/sudo (the blocked one)
   ```
2. **Confirm the resolver picks gsudo:**
   ```sh
   cd ~/dev/my/dotfiles
   python -c "import sys; sys.path.insert(0,'src/dotfiles_pm'); import sudo_helper; print(sudo_helper.get_windows_elevation_binary()); print(sudo_helper.get_windows_elevation_command(['choco','upgrade','all','-y']))"
   # expect: gsudo
   #         ['gsudo', 'choco', 'upgrade', 'all', '-y']
   ```
3. **Confirm ChocoPM emits gsudo:**
   ```sh
   python -c "import sys; sys.path.insert(0,'src/dotfiles_pm'); from pms.choco import ChocoPM; p=ChocoPM(); print(p.upgrade_command); print(p.install_command)"
   # expect gsudo-prefixed lists
   ```
4. **Dry-run the real path (choco has no true dry-run for `upgrade all`; use `--noop`):**
   ```sh
   gsudo choco upgrade all --noop     # should enumerate without the org-policy error
   ```
5. **Run through the dotfiles PM flow (the original failing path):**
   ```sh
   python -m src.dotfiles_pm.pm upgrade choco
   # or whatever the normal update entrypoint is (e.g. `just` update target)
   ```
   **Expect:** no "Sudo is disabled by your organization's policy" (`-2147023636`); choco upgrades proceed under gsudo elevation.
6. **Fallback sanity (optional):** on a machine WITHOUT gsudo but WITH a working sudo, or via override:
   ```sh
   DOTFILES_WINDOWS_ELEVATION=sudo python -c "import sys; sys.path.insert(0,'src/dotfiles_pm'); import sudo_helper; print(sudo_helper.get_windows_elevation_binary())"
   # expect: sudo
   ```

## Assumptions stated

- No `docs/protocols/child-bootstrap.md` and no existing retros dir exist in this repo; the bootstrap baseline was inlined in the kickoff, so I proceeded and created `docs/retros/`.
- `DOTFILES_WINDOWS_ELEVATION` env override was added (not explicitly required) to mirror the existing `DOTFILES_SUDO_MODE` escape hatch — consistent with the file's design, and useful for the fallback test above.
- Default-when-neither-found returns `gsudo` (the preferred binary) rather than raising — keeps the resolver total/pure and lets the executor surface a normal "command not found" instead of a Python exception.

## Verdict

good

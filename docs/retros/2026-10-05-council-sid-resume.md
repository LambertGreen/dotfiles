# Retro — `ai_council` resumes the Council by its recorded session id

- **Machine:** lgreen-macp (laptop_work_mac)
- **Date:** 2026-10-05
- **Branch:** `feature/council-sid-resume` (off `origin/master` 9be4c9e). **Unpushed, push gated.**
- **Commit:** `3a0850a` (fix + tests); this retro is a separate commit.
- **Mission marker:** MISSION-COUNCIL-SID-RESUME-2026-10-04. Council backlog #11.

## Kickoff Prompt

> Council backlog #11: the `ai_council` launcher must resume the Council by its recorded session id,
> not `claude --continue`. Spec = row #11 of `ai_council/docs/council-improvement-backlog.md`. Root
> cause in `ai_council/retros/council/2026-10-04-recover-rekey.md`: `claude --continue` resumes the
> newest session in the cwd; missions share `~/dev/my/ai_council`, so after a restart a mission can
> take the Council's seat. File: `configs/ai_council_common/dot-local/bin/ai_council`,
> `claude_argv()` `resume)` case, plus the matching description (sid vs fallback). Confirm
> `recover.sh --council-sid` prints b4a4033a-… (read-only). `$(claude_argv)` is unquoted at the call
> sites: the new output must word-split correctly and not break `--pick`/`--fresh`. Keep
> `--continue` only as the fallback and make the fallback say so on stderr. Tests: harness case if
> one exists, else `bash -n` + `shellcheck` + a hermetic check with a stub recover.sh (sid and
> fallback paths). Do NOT launch a real `ai_council` or restart herdr. Push gated; retro with
> `## Tool usage`; close per `handoff.md`.

Boilerplate (bootstrap, leading-token rule, `## Done`) follows
`ai_council/docs/protocols/mission-bootstrap.md` and `handoff.md`.

## What shipped

- `resolve_resume_sid()`, which runs only in resume mode. It runs
  `$AI_DIR/.claude/orchestrator/recover.sh --council-sid` and accepts the output only if it is a
  lowercase UUID. Otherwise it leaves `RESUME_SID` empty and writes this to stderr:
  `ai_council: falling back to \`claude --continue\` (newest session in … — may not be the Council) — <why>`,
  where `<why>` is one of: recover.sh missing/not executable, recover.sh exit≠0 (its stderr is
  included, e.g. `no role:council start recorded in …`), or output that isn't a sid.
- `claude_argv` resume → `claude --resume <sid>` or `claude --continue`.
- `mode_label` resume → `resuming Council session <sid>` or
  `resuming newest session in cwd — fallback, no recorded Council sid`.
- Header usage text updated. The `--help` `sed` range was bumped from `2,20p` to `2,21p` for the added line.
- `tests/test_ai_council_launcher.py` with 10 cases.

### Design choice: resolve once, at top level

The backlog patch put the `recover.sh` call inside `claude_argv`. That doesn't work well here:
`claude_argv` and `mode_label` are both called inside `$(…)`. So recover.sh would run twice, a
fallback warning would print twice, and the label couldn't tell which path `claude_argv` took.
`resolve_resume_sid` is called once, just before each "waking Claude" echo, in both
`enter_council_workspace` and `wake_claude`. It runs after the "Claude already running" early
exits, so a no-op run doesn't consult recover.sh or warn.

### Word-splitting at the unquoted call sites

Both call sites (`herdr pane run "$wsid:p1" $(claude_argv)` and `exec $(claude_argv)`) split the
output on whitespace. A UUID has no whitespace or glob characters, and the regex enforces that.
So `claude --resume <sid>` becomes exactly three words. The tests check this through both real call sites.

## Verification

- `recover.sh --council-sid` (read-only) → `b4a4033a-ebcf-4580-8b81-2a6fc1941e0b`. This matches the
  validation regex.
- `pytest tests/test_ai_council_launcher.py -v` → **10 passed**. Five cases × two call sites
  (`pane-run` = from another workspace via `herdr pane run`; `exec` = inside the Council workspace):
  - sid recorded → argv `claude --resume <sid>`, label names the sid, no warning
  - recover.sh missing → `claude --continue` + stderr warning naming the missing path
  - recover.sh exit 1 → `--continue` + warning carrying recover.sh's own reason
  - non-UUID output → `--continue` + warning quoting the output
  - `--pick` / `--fresh` → `claude --resume` / `claude`, and recover.sh isn't consulted (stderr empty)
- The tests run the real script with stub `herdr`, `claude` and `recover.sh` on a fake `$HOME`
  (same pattern as `tests/test_undeclared_packages.py`). The real herdr and Council pane are never touched.
- `shellcheck` clean, `bash -n` clean, `--help` renders. The pre-commit hooks (shellcheck, shebang)
  passed on commit.

## Live-ness: not live yet

`~/.local/bin/ai_council` is a stow symlink into the **primary** checkout (`~/dev/my/dotfiles`,
on master). This branch changes nothing on PATH until it is **merged to master and pulled in
the primary checkout**. No re-stow is needed because the file already exists in the package.

**Follow-up verification for Lambert's next herdr restart:** run `ai_council`. Check that the wake
message says `resuming Council session <sid>` with no fallback warning. Then check that
`herdr agent list` shows `agent_session.value` on the "Jedi Council" seat equal to
`recover.sh --council-sid`.

## Tool usage

| Tool | Actions | Verdict |
|---|---|---|
| local git | check-ignore, add, commit | good |
| recover.sh | `--council-sid` (read-only) | good: printed the expected sid |
| shellcheck / bash -n | lint + syntax of launcher | good |
| pytest (`/opt/homebrew/bin/pytest`) | new launcher tests | good after fallback |
| pre-commit | hooks on commit | good |

### Failures / gaps
- **`python3 -m pytest`:** the first `python3` on PATH is Xcode's `/usr/bin/python3`, which has no
  pytest module. Remediation: call the Homebrew `pytest` binary directly. Not a catalog-worthy tool
  failure, just PATH order on this machine.
- **`bats`:** not installed. The dotfiles repo has no bats harness, so the tests use the existing
  pytest + stub-on-PATH pattern instead.
- **Keychain lock noise:** `fd` printed `x Error: could not acquire lock …/.keychain/…state.lock`
  on stderr. That comes from the shell profile's keychain init when shells start concurrently, not
  from fd. Harmless here; the output was intact.

## Open / deferred

- Push + draft PR: gated on Lambert.
- Merge → pull in primary → verify on the next restart (above).
- Backlog row #11: the Council marks it DONE (not edited by this mission).
- The `cortana` launcher (`cortana_common`) still uses `--continue`. That's out of scope: it was
  marked for later decommissioning (2026-09-12 retro), and whether `~/dev/my/ai` records a sid wasn't checked.

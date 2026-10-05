# Retro — herdr upgrade guard (`just upgrade` holds herdr back; `just herdr-upgrade` is the deliberate path)

- **Machine:** lgreen-macp (laptop_personal_mac, per `~/.dotfiles.env`)
- **Date:** 2026-10-05
- **Branch:** `feature/herdr-upgrade-guard` (off `origin/master` 74c1db0)
- **Mission marker:** MISSION-HERDR-UPGRADE-GUARD-2026-10-05. Council backlog #3.

## Kickoff Prompt

> Council backlog #3: a herdr upgrade bumps the protocol, and the forced server restart kills every
> pane. Evidence: on 2026-10-03, `brew upgrade` (via dotfiles-maintenance) took the herdr client to
> 0.9.3 (protocol 22) while the running server stayed on protocol 20. Every herdr call failed until
> `herdr server stop`, which closes all panes. Design it, with evidence, from these options or better:
> (a) the upgrade path detects a live herdr server and SKIPS herdr with a loud message naming the
> deliberate path, rather than pinning forever; (b) a deliberate `just herdr-upgrade` recipe that says
> up front it will restart the server and kill all panes, then does upgrade → server stop → relaunch
> `ai_council`, and refuses to run non-interactively; (c) note the cadence step in the
> dotfiles-maintenance skill (if it lives in ai_council, write the exact change into the retro).
> Decision logic in a script with stubbable `herdr`/`brew`, tested in the dotfiles harness;
> shellcheck + bash -n clean. HARD FLOOR: no `brew upgrade`, `herdr update`, `herdr server
> stop/restart`, or `ai_council` launch on this machine; read-only probes only. When green: push,
> PR, merge, ff-pull the primary checkout. Retro with `## Tool usage`; close per `handoff.md`.

Boilerplate (bootstrap, leading-token rule, `## Done`) follows
`ai_council/docs/protocols/mission-bootstrap.md` and `handoff.md`. The mission file
`.mission/herdr-upgrade-guard.org` named in the kickoff did not exist in the worktree, so the kickoff
text was the only contract.

## Evidence gathered (read-only)

| Probe | Result |
|---|---|
| `herdr --version` | `herdr 0.8.2` |
| `herdr status server --json` | `running, version 0.8.2, protocol 20, compatible true, restart_needed false, capabilities {live_handoff: true, …}`, session `council` |
| `herdr status client --json` | `version 0.8.2, protocol 20` |
| `herdr session list --json` | `default` stopped, `council` running. **Two sessions**, so the guard must check every session, not just the current one |
| `herdr --session default status server --json` | `not_running`. `--session` works as a global flag for `status`/`server` |
| `brew info --json=v2 herdr` | stable 0.9.3, installed 0.8.2, `pinned: false`, `outdated: true` |
| `brew outdated --json=v2` | herdr entry `{installed_versions:[0.8.2], current_version:0.9.3, pinned:false}`. Auto-update chatter is printed before the JSON |
| herdr docs (`herdr.dev/llms-full.txt`) | "Compatible release versions do not need to match"; live handoff is *experimental*, opt-in via `herdr update --handoff`; agent resume-after-restart ("same session back in the same pane after a Herdr server restart") needs **herdr ≥ 0.9.2** |

What the evidence decided:
- **Homebrew cannot tell us a release's protocol before it is installed.** So "would this upgrade
  change the protocol?" is unknowable up front, and the guard treats *any* herdr version change under a
  live server as a possible protocol bump. 0.8.2 → 0.9.3 bumped it 20 → 22.
- **Pinning was rejected.** `brew pin` makes herdr drop out of `brew outdated` and upgrades in silence.
  That is the "silently stale forever" failure the kickoff warns about. The repo has a pin precedent
  (`scripts/package-management/brew/setup-pinned-packages.sh`, for admin formulas), but it is not wired
  into any recipe, and it has exactly that drawback.
- **`herdr update --handoff` was not used.** It is experimental, and it installs outside Homebrew, so it
  would fight the Brewfile. It is untested across a protocol bump, and the hard floor rules out trying
  it here. It is noted below as a candidate.

## What shipped

### 1. `src/dotfiles_pm/herdr_guard.py`: the decision (Python, stdlib only, py3.9-safe)

`plan()` looks up `herdr` and `brew` on PATH, so tests stub them. It returns one of three actions:

| State | Action | What `just upgrade`'s brew step does |
|---|---|---|
| herdr not installed, or no session `running` | `upgrade-all` | `exec brew upgrade`, unchanged from before |
| any session running, **or `herdr session list` fails** (unknown means live) | `hold` | `exec brew upgrade <outdated formulae + casks, minus herdr, minus pinned>` with `HOMEBREW_NO_AUTO_UPDATE=1`, plus a `!!` banner: `HERDR HELD BACK: 0.8.2 -> 0.9.3 NOT upgraded … just herdr-upgrade` |
| live, and `brew outdated --json=v2` fails | `error` | runs nothing, exit 1, and says why. It never upgrades blind |

Details:
- While a server is live, the upgrade uses **explicit targets even when herdr is current**. A bare
  `brew upgrade` auto-updates first and could pull in a herdr release published a minute ago.
- If only herdr is outdated → "nothing else to upgrade", exit 0.
- **Existing skew is reported.** For each live session, `herdr --session S status server --json` is
  checked, and `compatible: false` prints `HERDR PROTOCOL SKEW … just herdr-upgrade`. That covers the
  2026-10-03 state, where the client was already upgraded.
- CLI: `brew-upgrade`, `status`, and `live-sessions` (used by the recipe).

### 2. `BrewPM.upgrade_command` → the guard

`env HOMEBREW_ACCEPT_EULA=Y python3 <abs>/herdr_guard.py brew-upgrade`. The gui/askpass form wraps the
same string. The EULA pre-acceptance (2026-10-02) still reaches brew through `os.execvpe`. `brew
bundle install` already uses `--no-upgrade`, and `brew upgrade --cask --greedy` (brew-cask PM) never
touches a formula, so `brew upgrade` was the only path that could bump herdr.

### 3. `just herdr-upgrade` → `scripts/package-management/herdr/herdr-upgrade.sh`: the deliberate path

1. It refuses unless **stdin and stdout are both TTYs** (exit 2). This was checked live: under the harness
   it printed the refusal and touched nothing.
2. It refuses **inside a herdr pane** (`HERDR_ENV=1`, exit 2). Stopping the server would kill the script
   between `stop` and the relaunch, so it must run from a plain terminal tab.
3. It prints `herdr_guard.py status`. If herdr is already current it exits 0 having done nothing.
4. It names every live session, says **"CLOSES EVERY PANE … the Council and all missions"**, and
   requires typing `restart`. Anything else → "Aborted; nothing changed."
5. `brew upgrade herdr`. On failure it stops with "servers left running, panes intact".
6. `herdr --session <s> server stop` for each live session. The new client stopping the old server is
   what worked on 2026-10-03.
7. `exec ai_council`. That attaches `herdr --session council`; run `ai_council` again inside to wake
   Claude by recorded sid (dotfiles#23).

### 4. `just herdr-upgrade-check`

Read-only `herdr_guard.py status`. Live output on this machine today:
```
live sessions: council
herdr: 0.8.2 -> 0.9.3 available; held back by `just upgrade`; run `just herdr-upgrade`.
```

## Verification

- `pytest tests/test_herdr_upgrade_guard.py tests/test_brew_eula.py` → **20 passed**. Full
  `pytest tests/` → **160 passed**.
- `tests/test_herdr_upgrade_guard.py` (16 cases) runs the real code against stub `herdr`/`brew`/`ai_council`
  on a PATH that holds only stubs and `/usr/bin:/bin`:
  - guard: herdr absent / no live server → bare `brew upgrade`. Live + herdr outdated → targets
    `ripgrep blender` (herdr and the pinned formula dropped, the cask kept), `NO_AUTO_UPDATE=1`, banner
    with versions, session and `just herdr-upgrade`. Live + herdr current → explicit targets, no banner.
    Only herdr outdated → no upgrade. Session list fails → held. Brew outdated fails → refuses. Skew is
    reported. `status` wording.
  - `BrewPM().upgrade_command` executed for real → goes through the guard, and `HOMEBREW_ACCEPT_EULA=Y`
    reaches brew.
  - recipe (on a real **pty** via `pty.openpty`, so the TTY gate is exercised rather than bypassed):
    no-TTY refusal with zero stub calls. Inside-herdr refusal. Wrong word → nothing changed. `restart`
    → exact order `brew upgrade herdr` → `server stop` ×2 sessions → `ai_council`. Upgrade failure →
    no stop, no relaunch. herdr current → no-op.
- `tests/test_brew_eula.py` assertions were updated for the new command shape. The EULA guarantee is unchanged.
- `shellcheck` clean, `bash -n` clean, `just --list` parses.

## Change for ai_council (the Council applies it; not in this repo)

The dotfiles-maintenance skill lives in `ai_council/skills/dotfiles-maintenance/`, so this mission
does not edit it. Exact changes:

**`skills/dotfiles-maintenance/SKILL.md`**: add under "Known wrinkles" (next to the post-OS-upgrade bullet):

```markdown
- **herdr is held back while a herdr server is live (dotfiles 2026-10-05, backlog #3).** `just upgrade`
  skips herdr whenever any herdr session is running (always true when the Council spawned the mission)
  and prints a `!! HERDR HELD BACK: <old> -> <new>` banner. This is expected, not an anomaly: record the
  held version under **Anomalies → held back**, and add a follow-up for Lambert: "run `just herdr-upgrade`
  from a plain terminal tab outside herdr (kills all panes, relaunches `ai_council`)". A
  `HERDR PROTOCOL SKEW` banner IS an anomaly (client already newer than a live server) — verdict
  `needs-attention`. The mission must NEVER run `just herdr-upgrade` (it refuses without a TTY anyway).
```

and in Phase 3 (evaluate), after the retro is drafted:

```markdown
- **Cadence step: herdr restart.** If the retro records a held-back herdr, tell Lambert in the close
  summary: "herdr <old>→<new> is waiting: `just herdr-upgrade` (outside herdr) when you can afford a
  restart." Check first with `just herdr-upgrade-check` (read-only).
```

**`skills/dotfiles-maintenance/KICKOFF-TEMPLATE.md`**: add `"Bash(just herdr-upgrade-check*)"` to the
allow-list, and this line in the `# Rules` section: "A `HERDR HELD BACK` banner from `just upgrade` is
expected; record it, don't work around it. Never run `just herdr-upgrade`."

**`docs/tools/cli/herdr.md`**: add to the actions table:

```markdown
| `herdr session list --json` | dotfiles `herdr_guard.py` | `{"sessions":[{name, running, session_dir, socket_path, default}]}` — the only way to see EVERY session (Council's `council` + Cortana's `default`); `status server` reports just the current one. |
| `herdr --session <s> status server --json` | dotfiles `herdr_guard.py` | `{running, version, protocol, compatible, restart_needed, capabilities{live_handoff,…}}`; `--session` is a global flag. |
```

and a section "Upgrades (2026-10-05)": `just upgrade` holds herdr while any session runs, and `just
herdr-upgrade` is the deliberate path (TTY-only, outside herdr). brew cannot report a release's
protocol before install. herdr ≥ 0.9.2 resumes agents in the same pane after a server restart
(`[session] resume_agents_on_restore`), so restarts after this first one should hurt less.
`herdr update --handoff` (experimental live handoff) is untested here.

## Tool usage

| Tool | Actions | Verdict |
|---|---|---|
| herdr | `--version`, `status server/client --json`, `session list --json`, `--session default status server --json`, `--help`, `server --help`, `status --help` (all read-only) | good |
| brew | `info --json=v2 herdr`, `outdated --json=v2` (read-only) | good. `outdated` auto-updated Homebrew and fetched portable-ruby first (not an upgrade of any formula) |
| WebFetch | herdr.dev `llms.txt`, then `llms-full.txt` | good. The index pointed to the full bundle with the handoff/resume facts |
| pytest (`/opt/homebrew/bin/pytest`) | new + full suite | good |
| shellcheck / bash -n / just --list | recipe script, justfile | good |
| just | `herdr-upgrade-check` (live, read-only); `herdr-upgrade` (live, harness has no TTY → refused, as designed) | good |
| gh / git | push, PR, merge, ff-pull primary | see Done |

### Failures / gaps
- **Mission file missing:** `.mission/herdr-upgrade-guard.org` was not in the worktree. I proceeded
  from the kickoff text.
- **`python3 -m pytest`:** Xcode's `python3` has no pytest. I used the Homebrew `pytest` binary (same as the
  sid-resume retro).
- **pre-commit `check-shebang-scripts-are-executable`:** the first commit was rejected because the
  new `herdr-upgrade.sh` and `herdr_guard.py` were written without `+x`. Remediation: `chmod +x`, then
  restage. Note that the Write tool creates files 0644.
- **`brew outdated` is not read-only on disk:** it triggers `brew update` (auto-update). It is harmless
  and changes no formula, but "read-only probe" is slightly generous.

## Open / deferred

- **Lambert, when convenient:** `just herdr-upgrade` from a plain terminal tab (not inside herdr) takes
  0.8.2 → 0.9.3. It kills all panes, then `ai_council` → `ai_council` inside to wake by sid. That run is
  also the live verification of dotfiles#23 and of this recipe's stop/relaunch path. Hermetic only so far.
- Candidate later: evaluate `herdr update --handoff` (live handoff, no pane loss) once herdr is ≥ 0.9.3
  and the feature is no longer experimental. It would replace the stop step.
- The `wsl_work_ubuntu` class also has herdr via linuxbrew. The guard is platform-neutral, and the
  recipe finds `/home/linuxbrew/.linuxbrew`. It has not been exercised there.
- Backlog row #3: the Council marks it DONE.

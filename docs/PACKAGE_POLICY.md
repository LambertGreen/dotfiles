# Package Policy: global vs project-local

Which tools belong in a Brewfile, which belong to a project, and how to decide
when a tool is installable from several sources (brew *and* pip/npm/cargo).

## The strategy: prefer local, don't police global

The naive approach is to keep globals pure and police anything that sneaks in.
That fails in practice. Agents install tools. Installers install tools. A
one-off experiment installs a tool. Policing requires vigilance forever, and
attention goes where the current fire is.

So the design assumes globals **will** appear, and makes them harmless:

> **Projects and editors resolve tools locally first. A global is only ever a
> fallback.**

The mechanism is `direnv`, and it is already in place:

- `direnv` is declared in the Brewfile.
- This repo's own `.envrc` does `layout pyenv 3.13.8` and installs
  `requirements.txt`, so entering the directory puts the project's tools first
  on `PATH`.
- Emacs picks this up per-buffer through `envrc-global-mode`
  (`configs/emacs_common/dot-emacs.d/config/init-utils.el`).

The payoff is that **nothing has to cooperate**. A shell, an editor, or an AI
agent running a command in the project directory gets the project's tools
without knowing anything about this policy. Verified: an agent shell in this
repo resolves `python3` and `pytest` to `.direnv/python-3.13/bin/`, not to
Homebrew.

Known gap: **Neovim has no direnv integration yet**, so Emacs and Neovim
currently disagree about the same project. Tracked in `TODO.org`.

## The three tiers

| Tier | Test | Home |
|------|------|------|
| **Environment** | Works on any file, any repo; version rarely matters | Brewfile |
| **Bootstrap** | Needed to *create* a project environment, so it cannot be project-local | Brewfile |
| **Project** | A wrong version silently changes *output* for a given repo | Project manifest — with a declared global fallback |

**The deciding question for tier 3:** *at the wrong version, would I get a wrong
result rather than an error?*

- `black`, `isort`, `yapf`, `prettier`, `ruff`, `pyright` → **yes**. Tier 3.
- `ripgrep`, `fd`, `jq`, `htop`, `pandoc` → **no**. Tier 1.

Tier 2 is the one that is easy to miss: `uv`, `pyenv`, `pyenv-virtualenv`,
`node`, `rustup`. These *cannot* be project-local — you need them to build the
project environment in the first place. They are globals on purpose.

## Declared fallbacks

Tier 3 tools are declared globally anyway, in the **Project-Tool Fallbacks**
section of the Brewfile, with a comment saying they are fallbacks.

This is deliberate. They will end up installed regardless, so the real choice
is between a *declared* fallback and *silent drift* — and silent drift is what
hurt: `isort` sat undeclared for over a year, was installed by both brew and
pip, and the pip script squatting on `/opt/homebrew/bin/isort` made `brew link`
fail and took the whole `brew upgrade` down with it.

**Exception — formatters.** Do not wire format-on-save to a global fallback. A
global `black` against a repo pinned to an older one reformats the file and
hands you a diff you never asked for. Wrong diagnostics from a stale language
server are recoverable; a silent reformat committed to history is not. Editors
should format only when a project-local formatter resolves.

## Greenfield projects

A new project starts by copying an `.envrc`. **This repo's own `.envrc` is the
reference** — it handles pyenv layout, requirements install, and pre-commit
hooks. That matters because it stays current through daily use, rather than
depending on a separate examples project being kept warm.

For **offline** greenfield work, the answer is a warm package cache (`uv` and
npm install from cache without network), not a global tool. A global installed
six months ago reintroduces exactly the version-skew being avoided: the new
project's behaviour becomes a function of machine state.

## AI tooling

- The AI **client** (`claude-code`) must run in any directory → tier 1,
  declared as a cask.
- AI **project** tooling belongs to `~/dev/my/ai`, which manages its own
  dependencies.

AI needs network access anyway, so the offline argument for globals does not
apply here.

## When a tool exists in brew *and* pip/npm/cargo

1. Pick **one** source and stick to it. Two copies is the isort failure.
2. Prefer the **language-ecosystem** source for tier 3 tools (pip/npm/cargo),
   because that is what a project can pin.
3. Prefer **brew** for tier 1 and tier 2.
4. Before adding a global, check whether a copy already exists from the other
   manager: `command -v <tool>` and look at the shebang. A
   `#!/opt/homebrew/opt/python@3.13/bin/python3.13` shebang means pip put it
   there, not brew.

## Enforcement

`just doctor-check-undeclared` reports installed-but-undeclared packages. It is
**report-only** and exits 0 — under this policy its job is not to enforce purity
but to make accumulated globals visible, and to explain a broken upgrade after
the fact.

It reports only leaf formulae installed on request (never dependencies), tracks
formula and cask namespaces separately, and distinguishes genuine upstream
renames from aliases and tap-qualified names.

## Related

- `docs/submodules.md` — the same "make the safe path the default" idea applied
  to git submodules.
- `machine-classes/<class>/brew/Brewfile` — the declarations themselves.

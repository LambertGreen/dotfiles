# Shell config design — the landing pad and the safe file

## The problem this solves

Tool installers (aisuite, devbar, conda, rustup, …) auto-append `export` lines to
`~/.zshrc`, `~/.bashrc`, and `~/.bash_profile`. They write **absolute paths for
the machine they ran on**, they do not ask, and they rewrite their own blocks in
place between sentinel markers (`# >>> aisuite >>>` … `# <<< aisuite <<<`,
`# devbar-managed-start` … `# devbar-managed-end`).

You cannot stop them and you cannot negotiate with them. The design assumes they
will clobber whatever is at that path, and arranges for that to be *survivable
and visible* rather than *prevented*.

## The split

| File | Tracked? | Role |
| --- | --- | --- |
| `~/.zshrc` (`configs/shell_common/dot-zshrc`) | **yes, deliberately** | **Landing pad.** Thin, sacrificial. The installers' target. ~46 lines, almost all comments. |
| `~/.zshrc.user` (`configs/shell_common/dot-zshrc.user`) | yes | **The big common file.** ~860 lines. All real configuration. Safe because no installer knows this path exists. |

Same shape for `.bashrc` and `.bash_profile`.

**The rule: put configuration in `.user`. Never in the pad.** The pad's job is to
source `.user` first (so our config has precedence) and then absorb whatever the
installers write below the injection marker.

## Why the pads stay tracked

Because **tracking is how we see what the appenders did.** The pad is a stow
symlink into this repo, so an installer writing to `~/.zshrc` writes into the
working tree, and `git diff` becomes the only window onto changes that were
otherwise made silently and without consent.

**Do not gitignore or untrack the pads.** It is tempting — it would stop
machine-specific paths from travelling between machines — but it trades a
*visible* problem for an *invisible* one. An untracked pad means an installer can
rewrite the login shell of every machine and leave no trace anyone will ever
look at.

The cost of tracking is real and is accepted knowingly: appender output shows up
as repo churn, and machine-specific absolute paths can travel on a careless
commit. That cost is the price of visibility.

## The burden, and the three legitimate responses

When `git status` shows a dirty pad, that is the system working. Look at the
diff, then choose:

1. **See it and leave it.** Let the pad sit dirty; don't commit. You have seen
   what the tool did — that was the point. This is the default.
2. **Revert it,** knowing it will come back the next time that tool runs.
   `git checkout -- configs/shell_common/dot-zshrc`. Reverting is not a fix and
   is not expected to be permanent.
3. **Commit it, guarded** — take the block into the repo so other machines can
   see it too, but make it safe to travel (next section).

All three are correct in different moments. What is *not* correct is committing
an appender block unexamined, or hiding the churn so the choice never comes up.

## The guard rule — what makes option 3 safe

Anything committed into the injection zone MUST be `$HOME`-relative and wrapped
in a `[[ -d … ]]` guard, so it goes inert on machines where that tool is not
installed. This is what "merge it, but don't let it apply locally" looks like in
practice:

```zsh
# >>> aisuite >>>
if [[ -d "$HOME/.aisuite" ]]; then
  export NODE_EXTRA_CA_CERTS="$HOME/.aisuite/conf/npm-sfdc-certs.pem"
  export PATH="$PATH:$HOME/.aisuite/bin:$HOME/.aisuite/bin/aliases"
fi
# <<< aisuite <<<
```

The hand-written DevBar block always did this correctly. The two auto-injected
blocks did not, and were corrected on 2026-09-01 (`cf28e18`).

**Expect an installer to revert its own block** — the sentinels are
idempotent-rewrite markers, so the tool overwrites everything between them on its
next run, on whichever machine that tool is installed on. When that happens, the
diff shows up, and you are back at the three responses above. That loop is the
design, not a failure of it.

### What the unguarded blocks actually cost

Concrete, from the 2026-09-01 maintenance run on the personal Mac:

- `/Users/lambert.green/.aisuite/bin` and `.../bin/aliases` were live on `PATH` —
  4 of `doctor-check-path`'s 10 reported errors.
- `NODE_EXTRA_CA_CERTS` pointed at a `~/.devbar` cert file that does not exist on
  that machine, producing `Warning: Ignoring extra certs … load failed` on
  **every** `npm` invocation, including inside the maintenance run itself.

Both went silent once the blocks were guarded. Verified under `env -i`: with
neither `~/.aisuite` nor `~/.devbar` present, the zone leaves
`NODE_EXTRA_CA_CERTS` unset and `PATH` untouched.

## There is no `~/.zshrc.local`

The pads used to source `~/.zshrc.local`, commented "machine-specific, gitignored
if exists." That was a **false promise** and has been removed:

- No installer writes there — they only ever target `~/.zshrc`. Nothing would
  ever populate it.
- No `.gitignore` rule ever existed for it.
- On the personal Mac the file had never been created at all.

It made the split look like it had a machine-local escape hatch when it had none,
which is worse than not offering one. If you need a genuine machine-local
override, put it in `.user` behind a `[[ -d … ]]` or hostname guard.

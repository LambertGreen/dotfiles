# GPG Config & Key Policy

Canonical GPG policy for these dotfiles. This file lives in `gnupg_common/`
(a docs-only dir, not a stow package); per-OS runtime config lives in the
stowed `gnupg_{linux,osx,win}/dot-gnupg/` dirs.

**Safe for public.** This dotfiles repo is public. Everything here — and
everything committed under `dot-gnupg/` — is non-secret behavior config or
public identifiers (key fingerprints, which are on every signed commit). No
private key material is ever committed.

---

## What is tracked vs. never tracked

`dot-gnupg/.gitignore` ignores everything (`*`) and re-allows only the static
config files:

| File | Tracked? | Contents |
|------|----------|----------|
| `gpg.conf` | yes | `use-agent`, `pinentry-mode loopback` |
| `gpg-agent.conf` | yes | cache TTLs, pinentry program, `enable-ssh-support` |
| secret keys, `pubring.kbx`, `trustdb.gpg`, sockets | **never** | live only on each machine |

Principle (shared with SSH): **config is tracked; keys are never tracked.**

---

## Why GPG is NOT a git submodule

The SSH `config` is a private submodule because its *content* is sensitive
(internal hostnames, IPs, usernames). GPG config has **nothing secret in it** —
only behavior flags — so a submodule would add git plumbing complexity
(detached-HEAD drift, a separate pin to keep in sync) for zero secrecy benefit.
The submodule boundary tracks *secrecy of content*, not "keys vs config".
Private keys stay off every repo regardless.

---

## Keys and identities (fingerprints are public)

| Key | Identity | Selected for repos under |
|-----|----------|--------------------------|
| `C1D12B816253EFFD` (ed25519) | `lambert.green@gmail.com` (personal) | `~/dev/my/**` |
| `150FD7ADE9091C9E3DDB1C0966C09F6FD3D4A735` (rsa4096) | `lambert.green@salesforce.com` (work) | `~/dev/work*/**` |

Context switching is automatic via `git` `includeIf "gitdir:…"` in
`configs/git_common/dot-common.gitconfig`, which pulls in
`git_my/dot-my.gitconfig` (personal signingkey) or
`git_work/dot-work.gitconfig` (work signingkey). `commit.gpgsign=true` globally,
so the correct key signs based purely on repo location.

This directory-driven, fingerprint-referenced model is *why* GPG stayed
coherent while SSH keys drifted — worth mirroring in the SSH migration.

---

## Bootstrap on a new machine

`just onetimesetup` runs `lgreen_onetimesetup_gpg_trust`, which sets ultimate
ownertrust for `C1D12B816253EFFD` and `66C09F6FD3D4A735` **if they are already
in the keyring** — it does not import them. Importing secret keys is a manual
step; see the private key-provisioning runbook (`SETUP.md` in the ssh submodule)
for the full new-machine sequence covering both SSH and GPG.

---

## Known exposure (accepted, tracked)

`configs/git_work/dot-work.gitconfig` publicly reveals the work email and work
signing-key fingerprint. Fingerprints are not secret, but this publicly links a
salesforce.com identity to this personal repo. Flagged for a future move of
`git_work` into a private location — see the migration plan in the ssh
submodule's `README.md`.

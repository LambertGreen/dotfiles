#!/usr/bin/env python3
"""
What `brew upgrade` leaves for us to check or put back afterwards.

Background (2026-10-05 personal maintenance run):

1. Exit status. `brew upgrade` downloads in parallel before it installs. A
   pre-fetch that fails (`curl: (92) HTTP/2 stream … INTERNAL_ERROR` on
   whatsapp) is retried by the install step and succeeds, yet brew still exits 1.
   That run upgraded all 160 packages and reported "❌ brew: Upgrade failed".
   So the exit status alone is not evidence: when brew fails, ask brew what is
   still outdated, and fail only if something we asked for still is.

2. `link: false`. The Brewfile declares `brew "docker", link: false` and
   `brew "sip", link: false`. `brew upgrade` relinks a formula it upgrades,
   regardless of the Brewfile. docker's relink also overwrote docker-desktop's
   shell-completion symlinks, which brew reports as
   "Overwrote symlinks from the docker-desktop cask". After the upgrade we
   unlink every `link: false` formula that is linked again, then relink the
   casks brew said it overwrote. That is the restore brew itself suggests.
   We relink only the named casks: one `brew link --cask` over every name
   `brew list --cask` prints aborts on any it can't resolve, such as
   `alfred4`, the Caskroom alias Homebrew left when it renamed that cask
   to `alfred@4`.
"""

import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Callable, Iterable, List, Optional, Set

try:
    from .pm_detect import get_machine_class_name
except ImportError:  # run as a script from src/dotfiles_pm (herdr_guard.py)
    from pm_detect import get_machine_class_name

DOTFILES_ROOT = Path(__file__).resolve().parent.parent.parent

_LINK_FALSE = re.compile(r'^\s*brew\s+"([^"]+)"[^#\n]*\blink:\s*false')
_OVERWROTE_CASK = re.compile(r'Overwrote symlinks from the (\S+) cask')

Runner = Callable[..., subprocess.CompletedProcess]


def machine_brewfile() -> Optional[Path]:
    """The current machine class's Brewfile, or None if there isn't one."""
    machine_class = get_machine_class_name()
    if not machine_class:
        return None
    brewfile = DOTFILES_ROOT / 'machine-classes' / machine_class / 'brew' / 'Brewfile'
    return brewfile if brewfile.is_file() else None


def link_false_formulae(brewfile: Path) -> List[str]:
    """Formula names declared `link: false`. Tap-qualified names keep only the formula."""
    names = []
    for line in brewfile.read_text().splitlines():
        m = _LINK_FALSE.match(line)
        if m:
            names.append(m.group(1).rsplit('/', 1)[-1])
    return names


def overwritten_casks(output: str) -> List[str]:
    """Casks whose symlinks brew reported overwriting, in order, de-duplicated."""
    return list(dict.fromkeys(_OVERWROTE_CASK.findall(output)))


def _brew_prefix(run: Runner) -> Optional[Path]:
    try:
        r = run(['brew', '--prefix'], capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired):
        return None
    prefix = r.stdout.strip() if r.returncode == 0 else ''
    return Path(prefix) if prefix else None


def reassert_unlinked(brewfile: Optional[Path], casks_to_relink: Iterable[str],
                      run: Runner = subprocess.run) -> List[str]:
    """Unlink relinked `link: false` formulae; relink casks brew overwrote.

    Returns the formulae it unlinked. Failures are reported, never raised: the
    packages are already upgraded, and this step only tidies links.
    """
    casks = list(casks_to_relink)
    names = link_false_formulae(brewfile) if brewfile else []
    linked: List[str] = []
    if names:
        prefix = _brew_prefix(run)
        if prefix is None:
            print('⚠️  brew --prefix failed; cannot re-check link: false formulae.',
                  file=sys.stderr)
        else:
            linked = [n for n in names
                      if (prefix / 'var' / 'homebrew' / 'linked' / n).is_symlink()]

    unlinked = []
    for name in linked:
        r = run(['brew', 'unlink', name], capture_output=True, text=True)
        if r.returncode == 0:
            unlinked.append(name)
        else:
            print(f'⚠️  brew unlink {name} failed: {r.stderr.strip()}', file=sys.stderr)
    if unlinked:
        print(f'🔗 Re-applied Brewfile `link: false`: unlinked {", ".join(unlinked)}.',
              file=sys.stderr)

    for cask in casks:
        r = run(['brew', 'link', '--cask', cask], capture_output=True, text=True)
        if r.returncode == 0:
            print(f'🔗 Relinked {cask} (brew upgrade overwrote its symlinks).', file=sys.stderr)
        else:
            print(f'⚠️  brew link --cask {cask} failed: {r.stderr.strip()}', file=sys.stderr)
    return unlinked


def still_outdated(names: Optional[Iterable[str]], outdated: dict,
                   exclude: Iterable[str] = ()) -> Set[str]:
    """Which packages remain outdated after an upgrade.

    names: what we asked brew to upgrade, or None for a bare `brew upgrade`
    (then anything outdated and not pinned counts). `exclude` covers names
    we deliberately held back, such as herdr.
    """
    skip = set(exclude)
    remaining = set()
    for kind in ('formulae', 'casks'):
        for entry in outdated.get(kind) or []:
            if entry.get('pinned') or entry.get('name') in skip:
                continue
            remaining.add(entry['name'])
    if names is not None:
        remaining &= set(names)
    return remaining


def stream_and_capture(argv: List[str], env: dict) -> 'tuple[int, str]':
    """Run argv, passing its output through unchanged, and return (rc, output).

    Chunked rather than line-based so brew's carriage-return progress output
    still reaches the terminal and log as it happens.
    """
    proc = subprocess.Popen(argv, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    chunks = []
    assert proc.stdout is not None
    out = sys.stdout.buffer
    while True:
        chunk = os.read(proc.stdout.fileno(), 65536)
        if not chunk:
            break
        out.write(chunk)
        out.flush()
        chunks.append(chunk)
    return proc.wait(), b''.join(chunks).decode('utf-8', errors='replace')

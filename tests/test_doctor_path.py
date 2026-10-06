"""
Tests for doctor-check-path's handling of macOS path_helper entries.

Background (2026-10-05 personal run): all 5 `doctor-check-path` errors were
PATH entries from /etc/paths.d (cryptexd bootstrap dirs and /pkg/env/global/bin
shipped with macOS 27, rvictl's /Library/Apple/usr/bin). None were dotfiles
drift, so the error count hid the signal it exists to give.
"""
import sys
from pathlib import Path
from unittest.mock import patch

PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from src.dotfiles_pm.doctor import PathDoctor  # noqa: E402


def _etc(tmp_path):
    etc = tmp_path / 'etc'
    (etc / 'paths.d').mkdir(parents=True)
    (etc / 'paths').write_text('/usr/bin\n/bin\n')
    (etc / 'paths.d' / '10-cryptex').write_text(
        '/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin\n')
    (etc / 'paths.d' / '10-pmk-global').write_text('/pkg/env/global/bin\n')
    return etc


def _doctor(tmp_path, path_entries, system='Darwin'):
    with patch('src.dotfiles_pm.doctor.platform.system', return_value=system):
        doctor = PathDoctor(etc_dir=_etc(tmp_path))
    with patch.dict('os.environ', {'PATH': ':'.join(path_entries)}):
        doctor.check_broken_paths()
    return doctor


def test_missing_path_helper_entries_are_warnings_naming_their_source(tmp_path):
    d = _doctor(tmp_path, ['/usr/bin', '/pkg/env/global/bin'])
    assert d.issues == []
    assert len(d.warnings) == 1
    assert d.warnings[0]['type'] == 'broken_system_path'
    assert '10-pmk-global' in d.warnings[0]['message']


def test_missing_shell_injected_entry_is_still_an_error(tmp_path):
    # The class of drift dotfiles can fix, e.g. the 2026-09-01 aisuite leak.
    d = _doctor(tmp_path, ['/Users/lambert.green/.aisuite/bin'])
    assert [i['path'] for i in d.issues] == ['/Users/lambert.green/.aisuite/bin']
    assert d.warnings == []


def test_existing_path_helper_entries_produce_nothing(tmp_path):
    d = _doctor(tmp_path, ['/usr/bin', '/bin'])
    assert d.issues == [] and d.warnings == []


def test_non_darwin_ignores_etc_paths(tmp_path):
    d = _doctor(tmp_path, ['/pkg/env/global/bin'], system='Linux')
    assert [i['path'] for i in d.issues] == ['/pkg/env/global/bin']

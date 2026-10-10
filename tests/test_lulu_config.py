"""
Tests for LuLu config snapshot/restore (src/dotfiles_pm/lulu_config.py).

LuLu stores rules as a binary NSKeyedArchiver plist and has no CLI export; its
UI Rules → Export.../Import... uses a JSON shape (Rule.toJSON / initFromJSON in
objective-see/LuLu). lulu_config.py decodes the archive into that same JSON so
the restore path is LuLu's own Import.

PRIVACY: the repo is public and real rules list every app + host on a machine.
Every fixture here is synthesized in code (fake apps, example.com/.test hosts).
Never paste real export output into this file.
"""
import datetime as dt
import json
import plistlib
import subprocess
import sys
from pathlib import Path
from typing import Any

import pytest

PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT / 'src' / 'dotfiles_pm'))

import lulu_config  # noqa: E402

UID = plistlib.UID
NS_EPOCH = dt.datetime(2001, 1, 1, tzinfo=dt.timezone.utc)


class _Archiver:
    """Minimal NSKeyedArchiver writer, enough to mimic LuLu's rules.plist."""

    def __init__(self):
        self.objects: list[Any] = ['$null']
        self.classes: dict[str, UID] = {}

    def _cls(self, name, parents):
        if name not in self.classes:
            self.objects.append({'$classname': name, '$classes': [name, *parents]})
            self.classes[name] = UID(len(self.objects) - 1)
        return self.classes[name]

    def add(self, value):
        if value is None:
            return UID(0)
        if isinstance(value, (str, int, float, bool)):
            self.objects.append(value)
            return UID(len(self.objects) - 1)
        idx = len(self.objects)
        self.objects.append(None)  # reserve slot; children come after
        if isinstance(value, dt.datetime):
            obj = {'NS.time': (value - NS_EPOCH).total_seconds(),
                   '$class': self._cls('NSDate', ['NSObject'])}
        elif isinstance(value, dict) and value.get('__class__') == 'Rule':
            obj = {k: self.add(v) for k, v in value.items() if k != '__class__'}
            obj['$class'] = self._cls('Rule', ['NSObject'])
        elif isinstance(value, dict):
            keys = [self.add(k) for k in value]
            objs = [self.add(v) for v in value.values()]
            obj = {'NS.keys': keys, 'NS.objects': objs,
                   '$class': self._cls('NSMutableDictionary', ['NSDictionary', 'NSObject'])}
        elif isinstance(value, set):
            obj = {'NS.objects': [self.add(v) for v in sorted(value)],
                   '$class': self._cls('NSMutableSet', ['NSSet', 'NSObject'])}
        elif isinstance(value, list):
            obj = {'NS.objects': [self.add(v) for v in value],
                   '$class': self._cls('NSMutableArray', ['NSArray', 'NSObject'])}
        else:
            raise TypeError(type(value))
        self.objects[idx] = obj
        return UID(idx)

    def dump(self, root, path):
        top = self.add(root)
        archive = {'$archiver': 'NSKeyedArchiver', '$version': 100000,
                   '$top': {'root': top}, '$objects': self.objects}
        path.write_bytes(plistlib.dumps(archive, fmt=plistlib.FMT_BINARY))


CREATED = dt.datetime(2025, 1, 2, 3, 4, 5, tzinfo=dt.timezone.utc)


def rule(key, path, addr, port='*', *, rtype=3, action=1, pid=None, uuid=None, scope=None):
    return {
        '__class__': 'Rule', 'key': key, 'uuid': uuid or f'uuid-{key}-{addr}-{port}',
        'pid': pid, 'path': path, 'name': Path(path).name,
        'csInfo': {'signatureIdentifier': key, 'signatureStatus': 0, 'signatureSigner': 3,
                   'signatureAuthorities': ['Developer ID Application: Example', 'Apple Root CA']},
        'endpointAddr': addr, 'isEndpointAddrRegex': 0, 'endpointHost': None, 'endpointPort': port,
        'type': rtype, 'scope': scope, 'action': action, 'isDisabled': None,
        'creation': CREATED, 'expiration': None,
    }


def synthetic_rules():
    return {
        'com.example.editor': {
            'rules': [
                rule('com.example.editor', '/Applications/Editor.app/Contents/MacOS/Editor', 'updates.example.com', '443'),
                rule('com.example.editor', '/Applications/Editor.app/Contents/MacOS/Editor', 'telemetry.example.com', action=0),
            ],
            'paths': {'/Applications/Editor.app/Contents/MacOS/Editor'},
        },
        'com.apple.thing': {
            'rules': [rule('com.apple.thing', '/usr/libexec/thing', '*', rtype=1)],
            'paths': set(),
        },
        'com.example.tool': {
            'rules': [
                rule('com.example.tool', '/usr/local/bin/tool', 'api.example.test', '443'),
                rule('com.example.tool', '/usr/local/bin/tool', 'tmp.example.test', pid=4242),
            ],
            'paths': set(),
        },
    }


SYNTH_PREFS = {
    'allowApple': True, 'allowInstalled': False, 'blockMode': False,
    'allowList': '', 'blockList': '/Users/someone/lulu/block.txt', 'useBlockList': 1,
    'alertShowOptions': 1, 'alertLastRuleScope': 2, 'alertLastRuleDuration': 101,
    'installTime': dt.datetime(2025, 1, 1),
}


@pytest.fixture
def live(tmp_path):
    rules_plist = tmp_path / 'live' / 'rules.plist'
    prefs_plist = tmp_path / 'live' / 'preferences.plist'
    rules_plist.parent.mkdir()
    _Archiver().dump(synthetic_rules(), rules_plist)
    prefs_plist.write_bytes(plistlib.dumps(SYNTH_PREFS))
    return rules_plist, prefs_plist


def run(live, *argv):
    rules_plist, prefs_plist = live
    return lulu_config.main(['--live-rules', str(rules_plist), '--live-prefs', str(prefs_plist), *argv])


class TestDecode:
    def test_round_trips_archive_into_python(self, live):
        archived = lulu_config.load_archived_rules(live[0])
        assert set(archived) == {'com.example.editor', 'com.apple.thing', 'com.example.tool'}
        editor = archived['com.example.editor']
        assert editor['paths'] == ['/Applications/Editor.app/Contents/MacOS/Editor']
        assert editor['rules'][0]['creation'] == CREATED
        assert editor['rules'][0]['pid'] is None

    def test_rejects_non_archiver_plist(self, tmp_path):
        p = tmp_path / 'x.plist'
        p.write_bytes(plistlib.dumps({'hello': 'world'}))
        with pytest.raises(ValueError):
            lulu_config.load_archived_rules(p)


class TestLuLuExportShape:
    def test_user_only_skips_apple_and_temporary_rules(self, live):
        export = lulu_config.to_lulu_export(lulu_config.load_archived_rules(live[0]))
        assert set(export) == {'com.example.editor', 'com.example.tool'}
        assert [r['endpointAddr'] for r in export['com.example.tool']] == ['api.example.test']

    def test_all_includes_non_user_but_never_temporary(self, live):
        export = lulu_config.to_lulu_export(lulu_config.load_archived_rules(live[0]), user_only=False)
        assert 'com.apple.thing' in export
        assert all('tmp.example.test' != r['endpointAddr'] for rs in export.values() for r in rs)

    def test_rule_matches_lulu_initFromJSON_types(self, live):
        export = lulu_config.to_lulu_export(lulu_config.load_archived_rules(live[0]))
        r = export['com.example.tool'][0]
        for field in ('key', 'uuid', 'path', 'name', 'endpointAddr', 'endpointPort'):
            assert isinstance(r[field], str), field
        for field in ('type', 'scope', 'action', 'isEndpointAddrRegex'):
            assert type(r[field]) is int, field
        assert r['scope'] == 0  # nil scope → [nil intValue] == 0
        assert r['creation'] == '2025-01-02T03:04:05+0000'
        # nil optionals are omitted, exactly like Rule.toJSON
        assert not {'endpointHost', 'expiration', 'isDisabled', 'pid'} & r.keys()
        assert r['csInfo']['signatureAuthorities'] == ['Apple Root CA', 'Developer ID Application: Example']

    def test_rules_sorted_for_stable_diffs(self, live):
        export = lulu_config.to_lulu_export(lulu_config.load_archived_rules(live[0]))
        addrs = [r['endpointAddr'] for r in export['com.example.editor']]
        assert addrs == sorted(addrs)


class TestPrefs:
    def test_drops_volatile_and_hides_home(self, live):
        prefs = lulu_config.load_prefs(live[1], home='/Users/someone')
        assert not {'installTime', 'alertLastRuleScope', 'alertLastRuleDuration'} & prefs.keys()
        assert prefs['alertShowOptions'] == 1
        assert prefs['blockList'] == '$HOME/lulu/block.txt'
        assert list(prefs) == sorted(prefs)


class TestCli:
    def test_export_is_idempotent(self, live, tmp_path, capsys):
        out = ['--rules-out', str(tmp_path / 's' / 'rules.json'), '--prefs-out', str(tmp_path / 's' / 'prefs.json')]
        assert run(live, 'export', *out) == 0
        first = (tmp_path / 's' / 'rules.json').read_text()
        assert run(live, 'export', *out) == 0
        assert (tmp_path / 's' / 'rules.json').read_text() == first
        assert first.endswith('\n')
        assert 'unchanged' in capsys.readouterr().out.splitlines()[-1]
        json.loads(first)  # strict JSON (pre-commit check-json)

    def test_check_in_sync_then_drift(self, live, tmp_path, capsys):
        snap = ['--rules-snapshot', str(tmp_path / 'rules.json'), '--prefs-snapshot', str(tmp_path / 'prefs.json')]
        run(live, 'export', '--rules-out', str(tmp_path / 'rules.json'), '--prefs-out', str(tmp_path / 'prefs.json'))
        assert run(live, 'check', *snap) == 0

        changed = synthetic_rules()
        changed['com.example.tool']['rules'].append(
            rule('com.example.tool', '/usr/local/bin/tool', 'new.example.test', '22'))
        changed['com.example.editor']['rules'].pop()
        changed['com.example.editor']['rules'][0]['action'] = 0
        _Archiver().dump(changed, live[0])
        prefs = dict(SYNTH_PREFS, blockMode=True)
        live[1].write_bytes(plistlib.dumps(prefs))

        capsys.readouterr()
        assert run(live, 'check', *snap) == 1
        out = capsys.readouterr().out
        assert '+ com.example.tool  new.example.test:22' in out
        assert '- com.example.editor  telemetry.example.com:*' in out
        assert '~ com.example.editor  updates.example.com:443' in out
        assert 'blockMode: live=true snapshot=false' in out

    def test_check_without_rules_snapshot_still_checks_prefs(self, live, tmp_path, capsys):
        run(live, 'export', '--rules-out', str(tmp_path / 'rules.json'), '--prefs-out', str(tmp_path / 'prefs.json'))
        rc = run(live, 'check', '--rules-snapshot', str(tmp_path / 'missing.json'),
                 '--prefs-snapshot', str(tmp_path / 'prefs.json'))
        assert rc == 0
        assert 'no snapshot' in capsys.readouterr().out

    @pytest.mark.parametrize('flag,mode', [((), 'merge'), (('--all',), 'FULL replace')])
    def test_restore_steps_names_import_mode(self, live, tmp_path, capsys, flag, mode):
        run(live, 'export', '--rules-out', str(tmp_path / 'rules.json'),
            '--prefs-out', str(tmp_path / 'prefs.json'), *flag)
        capsys.readouterr()
        assert run(live, 'restore-steps', '--rules-snapshot', str(tmp_path / 'rules.json'),
                   '--prefs-snapshot', str(tmp_path / 'prefs.json')) == 0
        out = capsys.readouterr().out
        assert mode in out
        assert 'Rules → Import...' in out

    def test_missing_lulu_is_a_clean_error(self, tmp_path, capsys):
        rc = lulu_config.main(['--live-rules', str(tmp_path / 'nope.plist'), 'export',
                               '--rules-out', str(tmp_path / 'r.json'), '--prefs-out', str(tmp_path / 'p.json')])
        assert rc == 2
        assert 'not found' in capsys.readouterr().err


class TestPrivacyGuard:
    """Rules snapshots must never be committable from inside the repo."""

    @pytest.mark.parametrize('path', [
        'machine-classes/laptop_personal_mac/lulu/rules.json',
        'machine-classes/laptop_work_mac/lulu/rules-all.json',
    ])
    def test_rules_snapshot_paths_are_gitignored(self, path):
        result = subprocess.run(['git', '-C', str(PROJECT_ROOT), 'check-ignore', '-q', '--no-index', path])
        assert result.returncode == 0, f'{path} is not gitignored'

    def test_prefs_snapshot_is_tracked_not_ignored(self):
        path = 'machine-classes/laptop_personal_mac/lulu/preferences.json'
        result = subprocess.run(['git', '-C', str(PROJECT_ROOT), 'check-ignore', '-q', '--no-index', path])
        assert result.returncode == 1

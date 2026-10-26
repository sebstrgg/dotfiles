#!/usr/bin/env python3
"""Exercise the real helper, statusline and keeper only inside temp HOMEs."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ClaudeConfig(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        self.env = {'HOME': str(self.home), 'PATH': str(self.bin) + ':' + os.environ['PATH'], 'TZ': 'UTC'}
        for name in ('gh', 'launchctl'):
            stub = self.bin / name
            stub.write_text('#!/bin/sh\nexit 99\n')
            stub.chmod(0o755)

    def helper(self, command, *args):
        result = subprocess.run([sys.executable, str(ROOT / 'scripts/claude-config.py'), command, *args], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_merge_one_key_backups_and_repeat(self):
        path = self.home / '.claude/settings.json'
        path.parent.mkdir()
        old = {'model': 'keep', 'env': {'PRIVATE_TEST_VALUE': 'local-only'}, 'hooks': {'Stop': []}, 'statusLine': {'command': 'old'}}
        path.write_text(json.dumps(old))
        self.helper('install', '--reload')
        self.helper('check')
        after = json.loads(path.read_text())
        self.assertEqual({k: v for k, v in after.items() if k != 'statusLine'}, {k: v for k, v in old.items() if k != 'statusLine'})
        backups = list((self.home / '.local/state/dotfiles/backups/.claude').glob('settings.json.*'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(json.loads(backups[0].read_text()), old)
        self.helper('install')
        self.helper('check')
        self.assertEqual(len(list(backups[0].parent.glob('settings.json.*'))), 1)

    def test_fresh_seeds_only_statusline(self):
        self.helper('install')
        data = json.loads((self.home / '.claude/settings.json').read_text())
        self.assertEqual(list(data), ['statusLine'])
        self.helper('check')

    def test_statusline_state_and_deduplicated_snapshot(self):
        fixture = {'model': {'display_name': 'Opus', 'id': 'claude-opus-5-5'}, 'session_id': 'fixture', 'effort': {'level': 'high'}, 'rate_limits': {'five_hour': {'used_percentage': 12, 'resets_at': 2000000000}}}
        for _ in range(2):
            result = subprocess.run(['bash', str(ROOT / 'claude/statusline.sh')], input=json.dumps(fixture), env=self.env, cwd=self.home, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('Opus 5.5', result.stdout)
            self.assertIn('usage', result.stdout)
        state = self.home / '.local/state/agent-setup'
        self.assertEqual(json.loads((state / 'claude-usage-state.json').read_text())['five_hour_pct'], 12)
        self.assertEqual(len((state / 'usage-snapshots.jsonl').read_text().splitlines()), 1)

    def test_keeper_records_reset_and_skips_active_window(self):
        stub = self.bin / 'claude'
        stub.write_text('#!/bin/sh\nprintf x >>"$HOME/calls"\nprintf \'%s\\n\' \'{"type":"rate_limit_event","rate_limit_info":{"unifiedWindows":{"five_hour":{"resetsAt":9999999999}}}}\'\n')
        stub.chmod(0o755)
        for _ in range(2):
            result = subprocess.run(['bash', str(ROOT / 'bin/claude-window-keeper')], env=self.env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.home / 'calls').read_text(), 'x')
        self.assertEqual((self.home / '.local/state/claude-window-keeper/resets_at').read_text().strip(), '9999999999')


if __name__ == '__main__':
    unittest.main()

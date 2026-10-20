#!/usr/bin/env python3
"""Behaviour of bin/effort-gate through its hook interface."""
import json
import subprocess
import tempfile
import unittest
import uuid
from pathlib import Path

GATE = Path(__file__).resolve().parents[1] / 'bin' / 'effort-gate'

EFFORT = """---
status: {status}
checkout: {checkout}
---

# Example

## Done when

| # | Item | Check on the real target | Status | Evidence |
|---|---|---|---|---|
| 1 | Login works | real browser | {first} | |
| 2 | Logout works | real browser | pass | screenshot |

## Next

Keep going.
"""


class EffortGate(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self.tmp.name).resolve() / 'repo'
        self.repo.mkdir()
        subprocess.run(['git', 'init', '-q', str(self.repo)], check=True)
        self.session = str(uuid.uuid4())

    def tearDown(self):
        self.tmp.cleanup()

    def write_effort(self, status='active', first='open', checkout=None):
        path = self.repo / '.scratch' / 'example' / 'effort.md'
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(EFFORT.format(status=status, first=first, checkout=checkout or self.repo))
        return path

    def run_gate(self, mode, cwd=None, event='Stop'):
        payload = {'session_id': self.session, 'cwd': str(cwd or self.repo), 'hook_event_name': event}
        result = subprocess.run(['python3', str(GATE), mode], input=json.dumps(payload),
                                capture_output=True, text=True, check=True)
        return json.loads(result.stdout) if result.stdout.strip() else None

    def test_no_effort_file_allows_stop(self):
        self.assertIsNone(self.run_gate('stop'))

    def test_open_item_blocks_stop_and_names_it(self):
        self.write_effort()
        output = self.run_gate('stop')
        self.assertEqual(output['decision'], 'block')
        self.assertIn('#1 Login works', output['reason'])
        self.assertNotIn('Logout', output['reason'])

    def test_stop_from_subdirectory_is_gated(self):
        self.write_effort()
        sub = self.repo / 'src'
        sub.mkdir()
        self.assertEqual(self.run_gate('stop', cwd=sub)['decision'], 'block')

    def test_all_passed_allows_stop(self):
        self.write_effort(first='pass')
        self.assertIsNone(self.run_gate('stop'))

    def test_failed_or_unknown_status_blocks_stop(self):
        for status in ('fail', 'verified?', ''):
            self.write_effort(first=status)
            self.session = str(uuid.uuid4())
            self.assertEqual(self.run_gate('stop')['decision'], 'block', status)

    def test_blocked_or_done_status_allows_stop(self):
        for status in ('blocked', 'done'):
            self.write_effort(status=status)
            self.assertIsNone(self.run_gate('stop'), status)

    def test_copy_in_another_checkout_is_ignored(self):
        self.write_effort(checkout='/somewhere/else')
        self.assertIsNone(self.run_gate('stop'))

    def test_repeated_blocks_without_progress_are_capped(self):
        self.write_effort()
        outputs = [self.run_gate('stop') for _ in range(6)]
        self.assertTrue(all(o and o['decision'] == 'block' for o in outputs[:5]))
        self.assertIsNone(outputs[5])

    def test_progress_resets_the_cap(self):
        path = self.write_effort()
        for _ in range(5):
            self.run_gate('stop')
        path.write_text(path.read_text().replace('| 2 | Logout works | real browser | pass |',
                                                 '| 2 | Logout works | real browser | open |'))
        self.assertEqual(self.run_gate('stop')['decision'], 'block')

    def test_context_points_back_at_the_effort_file(self):
        path = self.write_effort()
        output = self.run_gate('context', event='SessionStart')['hookSpecificOutput']
        self.assertEqual(output['hookEventName'], 'SessionStart')
        self.assertIn(str(path), output['additionalContext'])
        self.assertIn('#1 Login works', output['additionalContext'])

    def test_context_without_effort_is_silent(self):
        self.assertIsNone(self.run_gate('context', event='PostCompact'))


if __name__ == '__main__':
    unittest.main()

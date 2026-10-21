#!/usr/bin/env python3
"""Behaviour of bin/effort-gate through its hook interface."""
import json
import os
import shlex
import subprocess
import tempfile
import unittest
import uuid
from pathlib import Path

GATE = Path(__file__).resolve().parents[1] / 'bin' / 'effort-gate'

EFFORT = """---
status: {status}
checkout: {checkout}
session: {session}
---

# Example

## Done when

| # | Item | Check on the real target | Status | Evidence |
|---|---|---|---|---|
| 1 | Login works | real browser | {first} | {evidence} |
| 2 | Logout works | real browser | pass | screenshot |

## Blockers

None.

## Running tasks

| Task | Runtime, model, effort | Handle | Worktree / branch | State |
|---|---|---|---|---|
{task}

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

    def write_effort(self, status='active', first='open', checkout=None, task='', evidence=''):
        path = self.repo / '.scratch' / 'example' / 'effort.md'
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(EFFORT.format(status=status, first=first, checkout=checkout or self.repo,
                                      session=self.session, task=task,
                                      evidence=evidence))
        return path

    def run_gate(self, mode, cwd=None, event='Stop', session=None, runtime=None):
        payload = {'session_id': session or self.session, 'cwd': str(cwd or self.repo),
                   'hook_event_name': event}
        command = ['python3', str(GATE), mode, *([runtime] if runtime else [])]
        result = subprocess.run(command, input=json.dumps(payload),
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

    def test_block_asks_for_a_cross_family_verify_and_a_report(self):
        self.write_effort()
        reason = self.run_gate('stop')['reason']
        self.assertIn('other model family', reason)
        self.assertIn('report', reason)

    def test_running_task_lets_a_runtime_that_wakes_on_it_stop(self):
        self.write_effort(task='| Export | Bash, background | bg-1 | main | running |')
        for _ in range(5):
            self.assertIsNone(self.run_gate('stop', runtime='claude'))

    def test_running_task_holds_other_runtimes_for_a_blocking_wait(self):
        self.write_effort(task='| Export | codex exec | run-7 | main | running since 09:10 |')
        output = self.run_gate('stop')
        self.assertEqual(output['decision'], 'block')
        self.assertIn('Export', output['reason'])
        self.assertIn('blocking wait', output['reason'])

    def test_stale_running_task_still_ends_in_blocked(self):
        for runtime in ('claude', None):
            self.session = str(uuid.uuid4())
            path = self.write_effort(task='| Export | Bash | bg-1 | main | running |')
            outputs = [self.run_gate('stop', runtime=runtime) for _ in range(6)]
            self.assertIn('marked blocked', outputs[5]['systemMessage'], runtime)
            self.assertIn('status: blocked', path.read_text(), runtime)

    def test_a_task_changing_state_counts_as_progress(self):
        path = self.write_effort(task='| Export | codex exec | run-7 | main | running |')
        for _ in range(5):
            self.run_gate('stop')
        path.write_text(path.read_text().replace('| running |', '| running, 80% |'))
        self.assertEqual(self.run_gate('stop')['decision'], 'block')

    def test_new_evidence_on_an_open_item_counts_as_progress(self):
        path = self.write_effort()
        for _ in range(5):
            self.run_gate('stop')
        path.write_text(path.read_text().replace('| open |  |', '| open | first check ran |'))
        self.assertEqual(self.run_gate('stop')['decision'], 'block')
        self.assertIn('status: active', path.read_text())

    def test_finished_task_does_not_count_as_running(self):
        self.write_effort(task='| Export | Bash | bg-1 | main | finished |')
        self.assertEqual(self.run_gate('stop', runtime='claude')['decision'], 'block')

    def test_stop_from_subdirectory_is_gated(self):
        self.write_effort()
        sub = self.repo / 'src'
        sub.mkdir()
        self.assertEqual(self.run_gate('stop', cwd=sub)['decision'], 'block')

    def test_all_passed_allows_stop(self):
        self.write_effort(first='pass')
        self.assertIsNone(self.run_gate('stop'))

    def test_pass_backed_only_by_a_substitute_stays_open(self):
        self.write_effort(first='pass', evidence='Substitute: mocked API, live endpoint unreachable')
        output = self.run_gate('stop')
        self.assertEqual(output['decision'], 'block')
        self.assertIn('#1 Login works (substitute evidence)', output['reason'])
        self.assertIn('substitute check never makes an item `pass`', output['reason'])

    def test_escaped_pipe_in_evidence_keeps_the_substitute_label(self):
        self.write_effort(first='pass', evidence='curl -s host \\| grep ok (substitute: staging)')
        self.assertIn('(substitute evidence)', self.run_gate('stop')['reason'])

    def test_blocked_item_with_substitute_evidence_allows_stop(self):
        self.write_effort(first='blocked', evidence='substitute only; needs the live API key')
        self.assertIsNone(self.run_gate('stop'))

    def test_failed_or_unknown_status_blocks_stop(self):
        for status in ('fail', 'verified?', ''):
            self.session = str(uuid.uuid4())
            self.write_effort(first=status)
            self.assertEqual(self.run_gate('stop')['decision'], 'block', status)

    def test_blocked_or_done_status_allows_stop(self):
        for status in ('blocked', 'done'):
            self.write_effort(status=status)
            self.assertIsNone(self.run_gate('stop'), status)

    def test_copy_in_another_checkout_is_ignored(self):
        self.write_effort(checkout='/somewhere/else')
        self.assertIsNone(self.run_gate('stop'))

    def test_other_sessions_in_the_checkout_are_never_gated(self):
        path = self.write_effort()
        before = path.read_text()
        other = str(uuid.uuid4())
        for _ in range(7):
            self.assertIsNone(self.run_gate('stop', session=other))
        self.assertIsNone(self.run_gate('context', event='SessionStart', session=other))
        self.assertEqual(path.read_text(), before)

    def test_effort_without_owner_is_not_gated(self):
        path = self.write_effort()
        path.write_text(path.read_text().replace(f'session: {self.session}\n', ''))
        self.assertIsNone(self.run_gate('stop'))

    def test_event_without_session_never_matches(self):
        path = self.write_effort()
        path.write_text(path.read_text().replace(f'session: {self.session}', 'session:'))
        payload = {'cwd': str(self.repo), 'hook_event_name': 'Stop'}
        result = subprocess.run(['python3', str(GATE), 'stop'], input=json.dumps(payload),
                                capture_output=True, text=True, check=True)
        self.assertEqual(result.stdout.strip(), '')

    def test_new_outside_an_agent_session_refuses(self):
        result = self.run_command('new', 'login')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('no session id', result.stderr)
        self.assertFalse((self.repo / '.scratch' / 'login').exists())

    def test_stall_marks_effort_blocked_and_warns(self):
        path = self.write_effort()
        outputs = [self.run_gate('stop') for _ in range(6)]
        self.assertTrue(all(o and o['decision'] == 'block' for o in outputs[:5]))
        self.assertNotIn('decision', outputs[5])
        self.assertIn('marked blocked', outputs[5]['systemMessage'])
        text = path.read_text()
        self.assertIn('status: blocked', text)
        self.assertIn('without progress on: #1 Login works', text)
        self.assertNotIn('None.', text)
        self.assertIn('## Next', text)
        self.assertIsNone(self.run_gate('stop'))

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

    def run_command(self, *args, env_ids=None, runtime=None):
        """Run a subcommand as an agent shell would; `runtime` names the nearest
        agent process (a shell run through a symlink of that name)."""
        env = {k: v for k, v in os.environ.items() if k not in ('CODEX_THREAD_ID', 'CLAUDE_CODE_SESSION_ID')}
        env.update(env_ids or {})
        command = ['python3', str(GATE), *args]
        if runtime:
            shell = Path(self.tmp.name) / 'bin' / runtime
            shell.parent.mkdir(exist_ok=True)
            shell.unlink(missing_ok=True)
            shell.symlink_to('/bin/sh')
            command = [str(shell), '-c', f'{shlex.join(command)}; exit $?']
        return subprocess.run(command, cwd=self.repo, env=env, capture_output=True, text=True,
                              check=False)

    def test_new_creates_an_owned_effort_and_ignores_scratch(self):
        result = self.run_command('new', 'login', env_ids={'CODEX_THREAD_ID': self.session})
        self.assertEqual(result.returncode, 0, result.stderr)
        path = self.repo / '.scratch' / 'login' / 'effort.md'
        text = path.read_text()
        self.assertIn(f'checkout: {self.repo}\n', text)
        self.assertIn(f'session: {self.session}\n', text)
        self.assertFalse((self.repo / '.gitignore').exists())
        status = subprocess.run(['git', '-C', str(self.repo), 'status', '--porcelain'],
                                capture_output=True, text=True, check=True).stdout
        self.assertEqual(status, '')
        self.assertEqual(self.run_gate('stop')['decision'], 'block')

    def test_new_keeps_an_existing_effort(self):
        path = self.write_effort()
        result = self.run_command('new', 'example', env_ids={'CODEX_THREAD_ID': 'someone-else'})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('claim', result.stderr)
        self.assertIn(f'session: {self.session}', path.read_text())

    def test_claim_moves_the_gate_to_the_new_owner(self):
        path = self.write_effort()
        successor = str(uuid.uuid4())
        result = self.run_command('claim', str(path), env_ids={'CLAUDE_CODE_SESSION_ID': successor})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.run_gate('stop', session=successor)['decision'], 'block')
        self.assertIsNone(self.run_gate('stop'))

    def test_nearest_runtime_decides_the_owner(self):
        path = self.write_effort()
        ids = {'CODEX_THREAD_ID': 'codex-thread', 'CLAUDE_CODE_SESSION_ID': 'claude-session'}
        for runtime, expected in (('codex', 'codex-thread'), ('claude', 'claude-session')):
            result = self.run_command('claim', str(path), env_ids=ids, runtime=runtime)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(f'session: {expected}\n', path.read_text(), runtime)

    def test_context_without_effort_is_silent(self):
        self.assertIsNone(self.run_gate('context', event='PostCompact'))


if __name__ == '__main__':
    unittest.main()

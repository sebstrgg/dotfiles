#!/usr/bin/env python3
"""Behaviour of bin/effort-gate through its hook interface."""
import hashlib
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

## Brief

**Not approved:** {not_approved}

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

    def write_effort(self, status='active', first='open', checkout=None, task='', evidence='',
                     not_approved='None.'):
        path = self.repo / '.scratch' / 'example' / 'effort.md'
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(EFFORT.format(status=status, first=first, checkout=checkout or self.repo,
                                      session=self.session, task=task,
                                      evidence=evidence, not_approved=not_approved))
        return path

    def run_gate(self, mode, cwd=None, event='Stop', session=None, runtime=None, last=None,
                 role=None, t3=False):
        """Run a hook as the runtime would; `role` marks a run started by agent-run."""
        payload = {'session_id': session or self.session, 'cwd': str(cwd or self.repo),
                   'hook_event_name': event}
        if last is not None:
            payload['last_assistant_message'] = last
        env = {k: v for k, v in os.environ.items() if k not in ('AGENT_RUN_ROLE', 'T3CODE_CLI_PATH')}
        if t3:
            env['T3CODE_CLI_PATH'] = '/usr/local/bin/t3'
        if role:
            env['AGENT_RUN_ROLE'] = role
        command = ['python3', str(GATE), mode, *([runtime] if runtime else [])]
        result = subprocess.run(command, input=json.dumps(payload), env=env,
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

    def test_done_when_outside_the_template_table_is_held(self):
        path = self.write_effort()
        text = path.read_text()
        table = text[text.index('| # | Item'):text.index('## Blockers')]
        path.write_text(text.replace(table, '1. Login works\n2. Logout works\n\n'))
        self.assertIn('template table', self.run_gate('stop')['reason'])
        context = self.run_gate('context', event='SessionStart')['hookSpecificOutput']
        self.assertIn('template table', context['additionalContext'])
        path.write_text(path.read_text().replace('status: active', 'status: done'))
        self.assertIn('template table', self.run_gate('stop')['reason'])

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

    def test_under_t3_a_running_task_allows_stop_without_a_heartbeat(self):
        self.write_effort(task='| Export | Bash, background | bg-1 | main | running |')
        self.assertIsNone(self.run_gate('stop', runtime='claude', t3=True))
        reason = self.run_gate('stop', t3=True)['reason']
        self.assertIn('blocking wait', reason)
        self.assertNotIn('heartbeat', reason.lower())

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

    def test_done_with_pass_items_and_no_runs_folder_allows_stop(self):
        path = self.write_effort(status='done', first='pass',
                                 evidence='Fresh verifier: t3-thread://v1/example')
        self.assertFalse((path.parent / 'runs').exists())
        for runtime in ('claude', None):
            self.assertIsNone(self.run_gate('stop', runtime=runtime))

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

    def test_blocked_status_allows_stop(self):
        self.write_effort(status='blocked')
        self.assertIsNone(self.run_gate('stop'))

    def test_done_with_an_unfinished_item_is_still_held(self):
        for first in ('open', 'pass (substitute)'):
            self.session = str(uuid.uuid4())
            self.write_effort(status='done', first=first)
            output = self.run_gate('stop')
            self.assertEqual(output['decision'], 'block', first)
            self.assertIn('#1 Login works', output['reason'], first)

    def test_stall_on_a_done_effort_marks_it_blocked(self):
        path = self.write_effort(status='done')
        outputs = [self.run_gate('stop') for _ in range(6)]
        self.assertIn('marked blocked', outputs[5]['systemMessage'])
        self.assertIn('status: blocked\n', path.read_text())
        self.assertIsNone(self.run_gate('stop'))

    def test_unusable_stall_counter_never_breaks_a_stop(self):
        name = hashlib.sha256(self.session.encode()).hexdigest()[:16]
        counter = Path(tempfile.gettempdir()) / 'effort-gate' / name
        counter.mkdir(parents=True)
        try:
            self.assertIsNone(self.run_gate('stop'))
            self.write_effort(first='pass')
            self.assertIsNone(self.run_gate('stop'))
        finally:
            counter.rmdir()

    def test_unusable_stall_counter_warns_instead_of_holding(self):
        name = hashlib.sha256(self.session.encode()).hexdigest()[:16]
        counter = Path(tempfile.gettempdir()) / 'effort-gate' / name
        counter.mkdir(parents=True)
        try:
            self.write_effort(status='done')
            output = self.run_gate('stop')
            self.assertNotIn('decision', output)
            self.assertIn('cannot keep its stop counter', output['systemMessage'])
        finally:
            counter.rmdir()

    def test_job_running_after_every_item_passed_still_waits(self):
        self.write_effort(first='pass', task='| Deploy | codex exec | run-8 | main | running |')
        output = self.run_gate('stop')
        self.assertEqual(output['decision'], 'block')
        self.assertIn('blocking wait', output['reason'])
        self.assertIsNone(self.run_gate('stop', runtime='claude', last='Waiting for the deploy.'))

    def test_an_unreadable_size_marker_lets_the_stop_through(self):
        path = self.write_effort(task='| Export | Bash, background | bg-1 | main | running |')
        path.write_text(path.read_text().replace('Keep going.', 'Keep going. ' * 2000))
        marker = path.parent / '.size-question'
        marker.write_text('')
        marker.chmod(0o200)
        try:
            for _ in range(3):
                self.assertIsNone(self.run_gate('stop', runtime='claude'))
        finally:
            marker.chmod(0o600)

    def test_an_oversized_effort_file_asks_once_for_a_rewrite(self):
        path = self.write_effort(task='| Export | Bash, background | bg-1 | main | running |')
        path.write_text(path.read_text().replace('Keep going.', 'Keep going. ' * 2000))
        output = self.run_gate('stop', runtime='claude')
        self.assertEqual(output['decision'], 'block')
        self.assertIn('Rewrite', output['reason'])
        self.assertIsNone(self.run_gate('stop', runtime='claude'))
        big = path.read_text()
        path.write_text(big.replace('Keep going. ' * 2000, 'Keep going. ' * 1700))
        self.assertIsNone(self.run_gate('stop', runtime='claude'))
        path.write_text(big)
        self.assertIsNone(self.run_gate('stop', runtime='claude'))
        path.write_text(big.replace('Keep going. ' * 2000, 'Keep going. ' * 3700))
        self.assertIn('Rewrite', self.run_gate('stop', runtime='claude')['reason'])

    def test_waiting_mid_effort_is_not_a_close(self):
        self.write_effort(task='| Export | Bash | bg-1 | main | running |',
                          not_approved='Going public.')
        self.assertIsNone(self.run_gate('stop', runtime='claude', last='Waiting for the export.'))

    def test_other_sessions_are_never_asked_to_close(self):
        self.write_effort(status='done', first='pass', not_approved='Going public.')
        self.assertIsNone(self.run_gate('stop', session=str(uuid.uuid4()), last='Done.'))

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

    def worktree(self, name):
        """A second worktree of the test repository, beside it."""
        self.commit_now()
        path = self.repo.parent / name
        subprocess.run(['git', '-C', str(self.repo), 'worktree', 'add', '-q', '-b', name, str(path)],
                       check=True)
        return path

    def test_effort_in_another_worktree_of_the_repository_is_gated(self):
        tree = self.worktree('feature')
        main_effort = self.write_effort()
        moved = tree / '.scratch' / 'example' / 'effort.md'
        moved.parent.mkdir(parents=True)
        moved.write_text(main_effort.read_text().replace(f'checkout: {self.repo}', f'checkout: {tree}'))
        main_effort.unlink()
        self.assertEqual(self.run_gate('stop')['decision'], 'block')
        self.assertIn(str(moved), self.run_gate('context', event='SessionStart')
                      ['hookSpecificOutput']['additionalContext'])

    def test_copy_in_a_worktree_naming_another_checkout_is_ignored(self):
        tree = self.worktree('feature')
        copy = tree / '.scratch' / 'example' / 'effort.md'
        copy.parent.mkdir(parents=True)
        copy.write_text(self.write_effort().read_text())
        (self.repo / '.scratch' / 'example' / 'effort.md').unlink()
        self.assertIsNone(self.run_gate('stop', cwd=tree))

    def test_a_delegated_run_is_never_gated(self):
        for role in ('work', 'verify', 'review'):
            self.write_effort(status='done', first='open', not_approved='Going public.')
            self.assertIsNone(self.run_gate('stop', role=role), role)
            self.assertIsNone(self.run_gate('context', event='SessionStart', role=role), role)

    def test_a_delegated_run_cannot_create_or_claim_an_effort(self):
        ids = {'CODEX_THREAD_ID': 'worker-thread', 'AGENT_RUN_ROLE': 'work'}
        created = self.run_command('new', 'login', env_ids=ids)
        self.assertNotEqual(created.returncode, 0)
        self.assertIn('orchestrator', created.stderr)
        self.assertFalse((self.repo / '.scratch' / 'login').exists())
        path = self.write_effort()
        claimed = self.run_command('claim', str(path), env_ids=ids)
        self.assertNotEqual(claimed.returncode, 0)
        self.assertIn(f'session: {self.session}\n', path.read_text())

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
        self.assertNotIn('## Blockers\n\nNone.', text)
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
        self.assertIn('engineering-workflow/SKILL.md again', output['additionalContext'])

    def run_command(self, *args, env_ids=None, runtime=None):
        """Run a subcommand as an agent shell would; `runtime` names the nearest
        agent process (a shell run through a symlink of that name)."""
        env = {k: v for k, v in os.environ.items()
               if k not in ('CODEX_THREAD_ID', 'CLAUDE_CODE_SESSION_ID', 'AGENT_RUN_ROLE')}
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

    def commit_now(self, message='change'):
        subprocess.run(['git', '-C', str(self.repo), '-c', 'user.name=t', '-c', 'user.email=t@t',
                        'commit', '-q', '--allow-empty', '-m', message], check=True)
        return subprocess.run(['git', '-C', str(self.repo), 'rev-parse', 'HEAD'],
                              capture_output=True, text=True, check=True).stdout.strip()

    def test_release_marks_head_and_records_the_run_in_the_effort(self):
        path = self.write_effort()
        head = self.commit_now()
        result = self.run_command('release', 'walk and review clean on the local build',
                                  env_ids={'CODEX_THREAD_ID': self.session})
        self.assertEqual(result.returncode, 0, result.stderr)
        marks = (self.repo / '.git' / 'agent-ci-release').read_text()
        self.assertTrue(marks.startswith(f'{head}\t'))
        self.assertIn('walk and review clean', marks)
        text = path.read_text()
        self.assertIn('## CI runs', text)
        self.assertIn(f'| {head[:12]} |', text)
        self.assertEqual(self.run_gate('stop')['decision'], 'block')  # the effort still parses

    def test_release_appends_to_an_existing_ci_runs_table(self):
        path = self.write_effort()
        path.write_text(path.read_text().replace(
            '## Running tasks', '## CI runs\n\n| Commit | Started | Why it is the release |\n'
            '|---|---|---|\n| abc | earlier | first |\n\n## Running tasks'))
        head = self.commit_now()
        self.run_command('release', 'second', env_ids={'CODEX_THREAD_ID': self.session})
        text = path.read_text()
        self.assertIn(f'| abc | earlier | first |\n| {head[:12]} |', text)

    def test_release_without_an_effort_still_marks_the_commit(self):
        head = self.commit_now()
        result = self.run_command('release', 'quick change')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(head, (self.repo / '.git' / 'agent-ci-release').read_text())

    def test_release_refuses_uncommitted_changes_and_delegated_runs(self):
        (self.repo / 'file').write_text('one')
        subprocess.run(['git', '-C', str(self.repo), 'add', 'file'], check=True)
        self.commit_now()
        (self.repo / 'file').write_text('two')
        result = self.run_command('release', 'why')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('uncommitted', result.stderr)
        subprocess.run(['git', '-C', str(self.repo), 'checkout', '-q', 'file'], check=True)
        (self.repo / 'new_source.py').write_text('')
        self.assertNotEqual(self.run_command('release', 'why').returncode, 0)
        (self.repo / 'new_source.py').unlink()
        self.assertEqual(self.run_command('release', 'why').returncode, 0)  # .scratch/ is ignored
        (self.repo / '.git' / 'agent-ci-release').unlink()
        result = self.run_command('release', 'why', env_ids={'AGENT_RUN_ROLE': 'work'})
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.repo / '.git' / 'agent-ci-release').exists())

    def test_context_without_effort_is_silent(self):
        self.assertIsNone(self.run_gate('context', event='PostCompact'))


if __name__ == '__main__':
    unittest.main()

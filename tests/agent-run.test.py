#!/usr/bin/env python3
"""Behaviour of bin/agent-run against stand-in `codex` and `claude` executables."""
import json
import os
import signal
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

AGENT_RUN = Path(__file__).resolve().parents[1] / 'bin' / 'agent-run'

# Each stand-in records its arguments, working directory, stdin and the
# environment that decides whether Claude is reachable, then behaves like the
# real CLI's non-interactive mode: events on stdout, the last message where the
# real one puts it.
FAKE = r'''#!/usr/bin/env python3
import json, os, sys, time
if os.environ.get('FAKE_PID'):
    import subprocess
    helper = subprocess.Popen(['sleep', '30'])
    with open(os.environ['FAKE_PID'], 'w') as pid:
        pid.write(f'{os.getpid()} {helper.pid}')
time.sleep(float(os.environ.get('FAKE_SLEEP', '0')))
prompt = sys.stdin.read()
record = {'argv': sys.argv[1:], 'cwd': os.getcwd(), 'stdin': prompt,
          'claude_config_dir': os.environ.get('CLAUDE_CONFIG_DIR'),
          'agent_run_role': os.environ.get('AGENT_RUN_ROLE'),
          'anthropic_api_key': 'ANTHROPIC_API_KEY' in os.environ,
          'claude_tokens': [name for name in ('ANTHROPIC_AUTH_TOKEN', 'CLAUDE_CODE_OAUTH_TOKEN')
                            if name in os.environ]}
with open(os.environ['FAKE_LOG'], 'w') as log:
    json.dump(record, log)
if os.path.basename(sys.argv[0]) == 'codex':
    print(json.dumps({'type': 'thread.started', 'thread_id': 'thread-1'}))
    last = sys.argv[sys.argv.index('-o') + 1]
    with open(last, 'w') as out:
        out.write('verdict: pass\n')
else:
    print(json.dumps({'type': 'system', 'subtype': 'init', 'session_id': 'session-1'}))
    print(json.dumps({'type': 'result', 'result': 'verdict: pass'}))
sys.exit(int(os.environ.get('FAKE_EXIT', '0')))
'''


class AgentRun(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name).resolve()
        bin_dir = root / 'bin'
        bin_dir.mkdir()
        for name in ('codex', 'claude'):
            (bin_dir / name).write_text(FAKE)
            (bin_dir / name).chmod(0o755)
        self.checkout = root / 'checkout'
        self.checkout.mkdir()
        self.run_dir = root / 'runs' / 'verify-1'
        self.run_dir.mkdir(parents=True)
        (self.run_dir / 'prompt.md').write_text('Check the done-when items.\n')
        self.log = root / 'fake.json'
        inherited = {k: v for k, v in os.environ.items() if k != 'AGENT_RUN_ROLE'}
        self.env = {**inherited, 'PATH': f'{bin_dir}:{os.environ["PATH"]}',
                    'FAKE_LOG': str(self.log), 'ANTHROPIC_API_KEY': 'test-key',
                    'ANTHROPIC_AUTH_TOKEN': 'test-token', 'CLAUDE_CODE_OAUTH_TOKEN': 'test-oauth',
                    'CLAUDE_CONFIG_DIR': str(root / 'claude-home')}

    def tearDown(self):
        self.tmp.cleanup()

    def agent_run(self, *args, check=True, **env):
        return subprocess.run(['python3', str(AGENT_RUN), *args], cwd=self.checkout,
                              env={**self.env, **env}, capture_output=True, text=True,
                              check=check, timeout=30)

    def start_and_wait(self, runtime, role, *options, **env):
        self.agent_run('start', runtime, role, str(self.run_dir), *options, **env)
        waited = self.agent_run('wait', str(self.run_dir), check=False)
        return waited, json.loads(self.log.read_text())

    def test_codex_verify_runs_pinned_with_network_and_claude_signed_out(self):
        waited, seen = self.start_and_wait('codex', 'verify')
        self.assertEqual(waited.returncode, 0, waited.stderr)
        self.assertIn('verdict: pass', waited.stdout)
        self.assertIn('thread-1', waited.stdout)
        argv = seen['argv']
        self.assertEqual(argv[:2], ['exec', '--json'])
        self.assertEqual(argv[argv.index('-m') + 1], 'gpt-6.1-sol')
        self.assertIn('model_reasoning_effort=high', argv)
        self.assertEqual(argv[argv.index('-s') + 1], 'danger-full-access')
        self.assertEqual(argv[-1], '-')
        self.assertEqual(seen['stdin'], 'Check the done-when items.\n')
        self.assertEqual(seen['cwd'], str(self.checkout))
        self.assertFalse(seen['anthropic_api_key'])
        self.assertEqual(seen['claude_tokens'], [])
        self.assertEqual(list(Path(seen['claude_config_dir']).iterdir()), [])
        for name in ('command.json', 'events.jsonl', 'last.md', 'stderr.log', 'exit'):
            self.assertTrue((self.run_dir / name).exists(), name)

    def test_codex_review_is_read_only_at_extra_high_effort(self):
        _, seen = self.start_and_wait('codex', 'review')
        argv = seen['argv']
        self.assertEqual(argv[argv.index('-s') + 1], 'read-only')
        self.assertIn('model_reasoning_effort=xhigh', argv)

    def test_codex_continuation_keeps_claude_reachable(self):
        _, seen = self.start_and_wait('codex', 'continue')
        self.assertTrue(seen['anthropic_api_key'])
        self.assertEqual(len(seen['claude_tokens']), 2)
        self.assertEqual(seen['claude_config_dir'], self.env['CLAUDE_CONFIG_DIR'])
        self.assertEqual(seen['argv'][seen['argv'].index('-s') + 1], 'danger-full-access')

    def test_claude_verify_runs_opus_without_edit_tools(self):
        waited, seen = self.start_and_wait('claude', 'verify')
        self.assertEqual(waited.returncode, 0, waited.stderr)
        self.assertIn('verdict: pass', waited.stdout)
        self.assertIn('session-1', waited.stdout)
        self.assertEqual((self.run_dir / 'last.md').read_text().strip(), 'verdict: pass')
        argv = seen['argv']
        self.assertEqual(argv[0], '-p')
        self.assertEqual(argv[argv.index('--model') + 1], 'opus')
        self.assertEqual(argv[argv.index('--effort') + 1], 'high')
        self.assertEqual(argv[argv.index('--disallowedTools') + 1:], ['Edit', 'Write', 'NotebookEdit'])
        self.assertNotIn('--permission-mode', argv)
        self.assertEqual(seen['stdin'], 'Check the done-when items.\n')

    def test_claude_work_keeps_edit_tools(self):
        _, seen = self.start_and_wait('claude', 'work')
        self.assertNotIn('--disallowedTools', seen['argv'])

    def test_model_and_effort_can_be_overridden(self):
        _, seen = self.start_and_wait('codex', 'work', '--model', 'gpt-6-astra', '--effort', 'xhigh')
        argv = seen['argv']
        self.assertEqual(argv[argv.index('-m') + 1], 'gpt-6-astra')
        self.assertIn('model_reasoning_effort=xhigh', argv)

    def test_start_returns_before_the_agent_finishes_and_wait_blocks(self):
        began = time.monotonic()
        self.agent_run('start', 'codex', 'verify', str(self.run_dir), FAKE_SLEEP='3')
        self.assertLess(time.monotonic() - began, 2)
        self.assertFalse((self.run_dir / 'exit').exists())
        waited = self.agent_run('wait', str(self.run_dir))
        self.assertIn('verdict: pass', waited.stdout)

    def test_stopping_the_run_stops_the_agent_and_its_children(self):
        pids = self.run_dir.parent / 'agent.pids'
        self.agent_run('start', 'codex', 'verify', str(self.run_dir), FAKE_SLEEP='30',
                       FAKE_PID=str(pids))
        for _ in range(50):
            if pids.exists() and len(pids.read_text().split()) == 2:
                break
            time.sleep(0.1)
        os.kill(int((self.run_dir / 'pid').read_text()), signal.SIGTERM)
        waited = self.agent_run('wait', str(self.run_dir), check=False)
        self.assertEqual(waited.returncode, 128 + signal.SIGTERM)
        for pid in map(int, pids.read_text().split()):
            for _ in range(20):
                try:
                    os.kill(pid, 0)
                except ProcessLookupError:
                    break
                time.sleep(0.1)
            else:
                self.fail(f'process {pid} of the stopped run is still alive')

    def test_agent_failure_is_the_wait_exit_code(self):
        waited, _ = self.start_and_wait('claude', 'verify', FAKE_EXIT='3')
        self.assertEqual(waited.returncode, 3)

    def test_runs_are_marked_delegated_except_a_continuation(self):
        for role, expected in (('work', 'work'), ('verify', 'verify'), ('review', 'review'),
                               ('continue', None)):
            self.run_dir = self.run_dir.parent / role
            self.run_dir.mkdir()
            (self.run_dir / 'prompt.md').write_text('Go.\n')
            _, seen = self.start_and_wait('codex', role)
            self.assertEqual(seen['agent_run_role'], expected, role)

    def test_a_delegated_run_cannot_start_another(self):
        refused = self.agent_run('start', 'codex', 'review', str(self.run_dir), check=False,
                                 AGENT_RUN_ROLE='work')
        self.assertNotEqual(refused.returncode, 0)
        self.assertIn('orchestrator', refused.stderr)
        self.assertFalse((self.run_dir / 'command.json').exists())

    def next_run(self, name):
        run_dir = self.run_dir.parent / name
        run_dir.mkdir()
        (run_dir / 'prompt.md').write_text('Carry on.\n')
        return run_dir

    def test_resume_continues_the_recorded_codex_thread_with_the_same_pins(self):
        self.start_and_wait('codex', 'verify', '--effort', 'xhigh')
        resumed = self.next_run('verify-2')
        self.agent_run('resume', str(self.run_dir), str(resumed))
        waited = self.agent_run('wait', str(resumed), check=False)
        self.assertEqual(waited.returncode, 0, waited.stderr)
        seen = json.loads(self.log.read_text())
        argv = seen['argv']
        self.assertEqual(argv[:4], ['exec', 'resume', '--json', '-m'])
        self.assertEqual(argv[argv.index('-m') + 1], 'gpt-6.1-sol')
        self.assertIn('model_reasoning_effort=xhigh', argv)
        self.assertIn('sandbox_mode=danger-full-access', argv)
        self.assertEqual(argv[-2:], ['thread-1', '-'])
        self.assertEqual(seen['stdin'], 'Carry on.\n')
        self.assertEqual(seen['agent_run_role'], 'verify')
        self.assertEqual(list(Path(seen['claude_config_dir']).iterdir()), [])
        record = json.loads((resumed / 'command.json').read_text())
        self.assertEqual((record['role'], record['resumes']), ('verify', str(self.run_dir)))

    def test_resume_continues_the_recorded_claude_session_with_the_same_pins(self):
        self.start_and_wait('claude', 'review')
        resumed = self.next_run('review-2')
        self.agent_run('resume', str(self.run_dir), str(resumed))
        self.agent_run('wait', str(resumed))
        argv = json.loads(self.log.read_text())['argv']
        self.assertEqual(argv[argv.index('--resume') + 1], 'session-1')
        self.assertEqual(argv[argv.index('--model') + 1], 'opus')
        self.assertIn('--disallowedTools', argv)

    def test_resume_refuses_a_run_still_going_or_without_a_session(self):
        self.agent_run('start', 'codex', 'work', str(self.run_dir), FAKE_SLEEP='3')
        early = self.agent_run('resume', str(self.run_dir), str(self.next_run('work-2')), check=False)
        self.assertNotEqual(early.returncode, 0)
        self.assertIn('still running', early.stderr)
        self.agent_run('wait', str(self.run_dir))
        (self.run_dir / 'events.jsonl').write_text('')
        empty = self.agent_run('resume', str(self.run_dir), str(self.next_run('work-3')), check=False)
        self.assertNotEqual(empty.returncode, 0)
        self.assertIn('no session', empty.stderr)

    def test_a_delegated_run_cannot_resume_another(self):
        self.start_and_wait('codex', 'work')
        refused = self.agent_run('resume', str(self.run_dir), str(self.next_run('work-2')),
                                 check=False, AGENT_RUN_ROLE='work')
        self.assertNotEqual(refused.returncode, 0)
        self.assertIn('orchestrator', refused.stderr)

    def test_refuses_a_run_folder_without_prompt_or_already_used(self):
        (self.run_dir / 'prompt.md').unlink()
        missing = self.agent_run('start', 'codex', 'verify', str(self.run_dir), check=False)
        self.assertNotEqual(missing.returncode, 0)
        self.assertIn('prompt.md', missing.stderr)
        (self.run_dir / 'prompt.md').write_text('again\n')
        self.start_and_wait('codex', 'verify')
        reused = self.agent_run('start', 'codex', 'verify', str(self.run_dir), check=False)
        self.assertNotEqual(reused.returncode, 0)
        self.assertIn('already', reused.stderr)


if __name__ == '__main__':
    unittest.main()

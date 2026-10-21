#!/usr/bin/env python3
"""Behaviour of bin/agent-tripwire through its PreToolUse hook interface."""
import json
import subprocess
import unittest
from pathlib import Path

TRIPWIRE = Path(__file__).resolve().parents[1] / 'bin' / 'agent-tripwire'


def decide(command, tool='Bash'):
    payload = {'hook_event_name': 'PreToolUse', 'tool_name': tool,
               'tool_input': {'command': command}}
    result = subprocess.run(['python3', str(TRIPWIRE)], input=json.dumps(payload),
                            capture_output=True, text=True, check=True)
    if not result.stdout.strip():
        return 'allow'
    return json.loads(result.stdout)['hookSpecificOutput']['permissionDecision']


class AgentTripwire(unittest.TestCase):
    def test_force_push_is_denied_in_any_spelling(self):
        for command in ('git push --force',
                        'git push -f origin main',
                        'git push -q --force origin v1.0.0',
                        'git push origin main --force',
                        'git push origin -f main',
                        'git push -uf origin main',
                        'git push --no-verify --force origin main',
                        'git -C . push --force origin main',
                        'git -c push.default=current push --force',
                        'git --no-pager push origin main -f',
                        'git push origin +main',
                        'git push origin +main:main',
                        'cd repo && git push --force origin main',
                        'git status; git push origin main --force',
                        'git fetch\ngit push --force origin main',
                        'FOO=1 git push --force',
                        'timeout 30 git push --force'):
            self.assertEqual(decide(command), 'deny', command)

    def test_ordinary_and_lease_protected_pushes_are_allowed(self):
        for command in ('git push',
                        'git push origin main',
                        'git push -u origin feature/x',
                        'git push --force-with-lease origin main',
                        'git push --force-with-lease=main:abc123 origin main',
                        'git push --force-if-includes --force-with-lease origin main',
                        'git push origin v1.0.0',
                        'git push -o ci.skip origin main',
                        'git log --format=%s -f',
                        'echo "never git push --force"',
                        'git commit -m "explain why --force is wrong"'):
            self.assertEqual(decide(command), 'allow', command)

    def test_codex_argv_command_is_read(self):
        self.assertEqual(decide(['bash', '-lc', 'git push origin main --force']), 'deny')
        self.assertEqual(decide(['git', 'push', '-f']), 'deny')
        self.assertEqual(decide(['git', 'push', 'origin', 'main']), 'allow')

    def test_other_tools_and_unparsable_commands_pass(self):
        self.assertEqual(decide('git push --force', tool='Edit'), 'allow')
        self.assertEqual(decide('echo "unterminated'), 'allow')


if __name__ == '__main__':
    unittest.main()

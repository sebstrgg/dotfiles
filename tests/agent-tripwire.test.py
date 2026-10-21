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
                        'timeout 30 git push --force',
                        'git push \\\n  --force origin main',
                        'git push -4f origin main',
                        'git push -f4 origin main',
                        'git push --mirror origin',
                        'command -- git push -f origin main',
                        'if true; then git push --force origin main; fi',
                        'for r in a b; do git push -f "$r" main; done',
                        'git status # check first\ngit push --force origin main',
                        "cat <<'EOF' > notes.txt\nit's fine\nEOF\ngit push --force origin main",
                        'git push --fo\\\nrce origin main',
                        'env -u GIT_TRACE git push -f origin main',
                        'sudo -u deploy git push --force origin main',
                        "printf '%s\\n' 'Use <<EOF for examples'\ngit push --force origin main",
                        "git push -o '#build' --force origin main",
                        'echo `git push -f`',
                        'echo "$(git push --force origin main)"',
                        'cat <<< "$message"\ngit push --force origin main',
                        'cat <<- EOF\nmessage\nEOF\ngit push --force origin main',
                        'cat <<-EOF\n\tmessage\n\tEOF\ngit push --force origin main',
                        'git commit -m "$(cat <<\'EOF\'\nIt\'s done (mostly)\nEOF\n)" && git push -f'):
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
                        'git push -ofast origin main',
                        'git push origin main -o +ci.skip',
                        'git push --push-option +x origin main',
                        'git push origin main  # never --force here',
                        'echo ok # example; git push --force is forbidden',
                        'command -p git push origin main',
                        "git commit -m 'Explain <<EOF and why git push --force is wrong'",
                        'git commit -m "$(cat <<\'EOF\'\nIt\'s done (mostly)\ngit push --force was wrong\nEOF\n)" && git push',
                        'echo "$(grep -c \'"x":"[^"]*"\' f)" && git push origin main',
                        "git commit -F - <<'EOF'\nExplain why\ngit push --force was wrong\nEOF",
                        'git log --format=%s -f',
                        'echo "never git push --force"',
                        'git commit -m "explain why --force is wrong"'):
            self.assertEqual(decide(command), 'allow', command)

    def test_process_listings_that_print_arguments_are_denied(self):
        for command in ('ps',
                        'ps aux',
                        'ps -ef',
                        'ps -ax',
                        '/bin/ps aux | grep node',
                        'sudo ps aux',
                        'ps -axo pid,command | rg "vite|node"',
                        'ps -o pid,args -p 123',
                        'ps -o args= -p 123',
                        'ps -eo pid,cmd',
                        'ps -axo pid,rss,comm,command',
                        'ps -o pid -o command -p 1',
                        'ps -opid,command',
                        "ps -A -o 'pid command'",
                        'ps --format pid,args',
                        'ps --format=pid,cmd',
                        'ps axo pid,command',
                        'ps -p 123',
                        'ps -axO rss',
                        'ps -f -o pid -p 1',
                        'ps -j -o pid',
                        'ps -lo pid',
                        'ps -v -o pid',
                        'ps -E -o pid,comm',
                        'ps auxo pid,comm',
                        'ps -axo pid,comm -M',
                        'ps -C -o command',
                        'ps ax -o pid,comm -u',
                        'ps axopid,args -o rss',
                        'ps -eo pid,args:100',
                        'ps ax -e -o pid,comm',
                        'pgrep -lf node',
                        'pgrep -fl node',
                        'pgrep -l -f node',
                        'pgrep -af node',
                        'pgrep -a node',
                        'pgrep --list-full node',
                        'echo "$(ps aux)"'):
            self.assertEqual(decide(command), 'deny', command)

    def test_process_listings_of_names_and_ids_are_allowed(self):
        for command in ('ps -axo pid,rss,comm',
                        'ps -axo pid,rss,comm | sort -k2 -n',
                        'ps -p 123 -o pid,comm',
                        'ps -o pid= -p 123',
                        'ps -o stat= -p 123',
                        'ps -eo pid,ppid,etime,comm',
                        'ps -axo pid,ucomm',
                        'ps -u sebastian -o pid,comm',
                        'ps -o pid=command -p 1',
                        'ps -o pid,comm:20',
                        'ps -p 123,456 -o pid=,comm=',
                        'ps -Ao pid,ppid,rss,comm',
                        'pgrep -x node',
                        'pgrep -f vite',
                        'pgrep -l node',
                        'pgrep -u sebastian -f vite',
                        'echo "ps aux"',
                        'git commit -m "never run ps aux"',
                        'man ps'):
            self.assertEqual(decide(command), 'allow', command)

    def test_ps_outside_the_names_only_form_is_refused(self):
        for command in ('ps axo pid,comm',
                        'ps t -o command',
                        'ps ax -C node',
                        'ps ax -g root',
                        'ps -g 100 -o pid,comm',
                        'ps -T -o pid,comm',
                        'ps --pid 1 -o pid',
                        'ps -o pid,comm 123'):
            self.assertEqual(decide(command), 'deny', command)

    def test_codex_argv_command_is_read(self):
        self.assertEqual(decide(['bash', '-lc', 'git push origin main --force']), 'deny')
        self.assertEqual(decide(['git', 'push', '-f']), 'deny')
        self.assertEqual(decide(['git', 'push', 'origin', 'main']), 'allow')

    def test_other_tools_and_unparsable_commands_pass(self):
        self.assertEqual(decide('git push --force', tool='Edit'), 'allow')
        self.assertEqual(decide('echo "unterminated'), 'allow')


if __name__ == '__main__':
    unittest.main()

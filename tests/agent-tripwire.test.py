#!/usr/bin/env python3
"""Behaviour of bin/agent-tripwire through its PreToolUse hook interface."""
import json
import os
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

TRIPWIRE = Path(__file__).resolve().parents[1] / 'bin' / 'agent-tripwire'


def decide(command, tool='Bash', cwd=None, env=None):
    """The hook's decision for `command`, run from `cwd` (a scratch folder outside
    any repository unless given)."""
    with tempfile.TemporaryDirectory() as outside:
        payload = {'hook_event_name': 'PreToolUse', 'tool_name': tool, 'cwd': str(cwd or outside),
                   'tool_input': {'command': command}}
        result = subprocess.run(['python3', str(TRIPWIRE)], input=json.dumps(payload),
                                capture_output=True, text=True, check=True, env=env)
    if not result.stdout.strip():
        return 'allow'
    return json.loads(result.stdout)['hookSpecificOutput']['permissionDecision']


def codex_decide(command, cwd):
    """Decision for a Codex event, which carries `turn_id` and the session's cwd."""
    payload = {'hook_event_name': 'PreToolUse', 'tool_name': 'Bash', 'turn_id': 't',
               'cwd': str(cwd), 'tool_input': {'command': command}}
    result = subprocess.run(['python3', str(TRIPWIRE)], input=json.dumps(payload),
                            capture_output=True, text=True, check=True)
    return json.loads(result.stdout)['hookSpecificOutput']['permissionDecision'] \
        if result.stdout.strip() else 'allow'


def git(repo, *args):
    return subprocess.run(['git', '-C', str(repo), *args], capture_output=True, text=True,
                          check=True).stdout.strip()


class FullCiRun(unittest.TestCase):
    """A checkout with workflows, an `origin` whose default branch is main, and a
    fake `gh` that reports the pull request on `feature` as draft or ready."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name).resolve()
        self.repo, origin, bin_dir = root / 'repo', root / 'origin.git', root / 'bin'
        subprocess.run(['git', 'init', '-q', '--bare', '-b', 'main', str(origin)], check=True)
        subprocess.run(['git', 'init', '-q', '-b', 'main', str(self.repo)], check=True)
        (self.repo / '.github' / 'workflows').mkdir(parents=True)
        (self.repo / '.github' / 'workflows' / 'ci.yml').write_text('on: push\n')
        git(self.repo, 'add', '.')
        git(self.repo, '-c', 'user.name=t', '-c', 'user.email=t@t', 'commit', '-qm', 'start')
        git(self.repo, 'remote', 'add', 'origin', str(origin))
        git(self.repo, 'push', '-q', 'origin', 'main')
        git(self.repo, 'remote', 'set-head', 'origin', 'main')
        git(self.repo, 'remote', 'set-url', 'origin', 'https://github.com/example/repo.git')
        git(self.repo, 'switch', '-qc', 'feature')
        bin_dir.mkdir()
        self.draft = root / 'draft'
        gh = bin_dir / 'gh'
        gh.write_text(f'''#!/bin/sh
case "$1 $2" in
  "pr view") case "$*" in
    *headRefOid*) git rev-parse HEAD ;;
    *) if [ -e {self.draft} ]; then echo "OPEN true"; else echo "OPEN false"; fi ;;
  esac ;;
  "run view") git rev-parse HEAD ;;
  "repo view") echo main ;;
  *) exit 1 ;;
esac
''')
        gh.chmod(0o755)
        self.env = {**os.environ, 'PATH': f'{bin_dir}:{os.environ["PATH"]}'}

    def tearDown(self):
        self.tmp.cleanup()

    def decide(self, command):
        return decide(command, cwd=self.repo, env=self.env)

    def release(self):
        marks = Path(git(self.repo, 'rev-parse', '--path-format=absolute', '--git-common-dir'))
        with open(marks / 'agent-ci-release', 'a') as file:
            file.write(f'{git(self.repo, "rev-parse", "HEAD")}\t2026-10-22 16:30 CEST\tdone\n')

    def test_every_command_that_starts_a_full_run_is_held_until_released(self):
        commands = ('git push origin HEAD:main', 'git push origin feature', 'git push',
                    'git -C . push -u origin feature', 'gh pr ready', 'gh pr ready 12',
                    'gh pr create --fill', 'gh workflow run ci.yml', 'gh run rerun 123',
                    'cargo fmt --check && gh pr ready')
        for command in commands:
            self.assertEqual(self.decide(command), 'deny', command)
        self.release()
        for command in commands:
            self.assertEqual(self.decide(command), 'allow', command)

    def test_a_commit_made_in_the_same_command_is_not_released(self):
        self.release()
        for command in ('git commit -qam fix && git push origin feature',
                        'git pull --rebase && gh pr ready', 'git -C . merge x; git push origin HEAD:main'):
            self.assertEqual(self.decide(command), 'deny', command)
        self.assertEqual(self.decide('git push origin feature && git commit -qam next'), 'allow')

    def test_a_new_commit_needs_its_own_release(self):
        self.release()
        git(self.repo, '-c', 'user.name=t', '-c', 'user.email=t@t', 'commit', '-q',
            '--allow-empty', '-m', 'another round')
        self.assertEqual(self.decide('git push origin feature'), 'deny')

    def test_iteration_on_a_draft_passes(self):
        self.draft.touch()
        for command in ('git push origin feature', 'git push', 'gh pr create --draft --fill',
                        'gh pr create -d', 'gh pr ready --undo', 'gh pr view',
                        'git push origin :old-branch', 'git push --tags'):
            self.assertEqual(self.decide(command), 'allow', command)

    def test_a_push_to_main_is_held_even_while_the_pull_request_is_draft(self):
        self.draft.touch()
        self.assertEqual(self.decide('git push origin feature:main'), 'deny')

    def test_the_reason_names_the_release_command(self):
        payload = {'hook_event_name': 'PreToolUse', 'tool_name': 'Bash', 'cwd': str(self.repo),
                   'tool_input': {'command': 'gh pr ready'}}
        output = json.loads(subprocess.run(['python3', str(TRIPWIRE)], input=json.dumps(payload),
                                           capture_output=True, text=True, check=True,
                                           env=self.env).stdout)
        self.assertIn('effort-gate release', output['hookSpecificOutput']['permissionDecisionReason'])

    def test_every_update_of_a_push_is_checked(self):
        self.release()
        git(self.repo, '-c', 'user.name=t', '-c', 'user.email=t@t', 'commit', '-q',
            '--allow-empty', '-m', 'untested')
        git(self.repo, 'branch', 'released', 'HEAD~1')
        for command in ('git push origin released:main HEAD:feature', 'git push origin --all',
                        'gh pr create --draft=false --fill', 'gh pr ready --undo=false'):
            self.assertEqual(self.decide(command), 'deny', command)

    def test_the_configured_push_destination_decides(self):
        self.draft.touch()
        git(self.repo, 'config', 'push.default', 'upstream')
        git(self.repo, 'config', 'branch.feature.remote', 'origin')
        git(self.repo, 'config', 'branch.feature.merge', 'refs/heads/main')
        self.assertEqual(self.decide('git push'), 'deny')

    def test_targets_are_read_from_the_named_ref_and_checkout(self):
        self.release()
        git(self.repo, 'branch', 'untested')
        git(self.repo, 'switch', '-q', 'untested')
        git(self.repo, '-c', 'user.name=t', '-c', 'user.email=t@t', 'commit', '-q',
            '--allow-empty', '-m', 'untested')
        git(self.repo, 'switch', '-q', 'feature')
        self.assertEqual(self.decide('gh pr create --head untested --fill'), 'deny')
        self.assertEqual(self.decide('git push origin untested:main'), 'deny')
        with tempfile.TemporaryDirectory() as elsewhere:
            self.assertEqual(decide(f'git -C {self.repo} push origin feature:main', cwd=elsewhere,
                                    env=self.env), 'allow')
            self.assertEqual(decide(f'cd {self.repo} && git push origin untested:main',
                                    cwd=elsewhere, env=self.env), 'deny')

    def test_help_dry_runs_other_remotes_and_other_repositories_pass(self):
        for command in ('git push --dry-run origin feature:main', 'git push -n origin HEAD:main',
                        'gh pr create --help', 'gh workflow run --help',
                        'git push /tmp/backup.git feature:main', 'gh pr ready 12 -R other/repo'):
            self.assertEqual(self.decide(command), 'allow', command)

    def test_flag_groups_dry_runs_repositories_and_remotes_are_read(self):
        self.draft.touch()
        self.assertEqual(self.decide('gh pr create -df'), 'allow')
        self.assertEqual(self.decide('gh pr create --dry-run --head feature --title t'), 'allow')
        for command in ('gh pr ready 12 -R example/repo', 'gh -R example/repo pr ready 12',
                        'git push origin main --tags', 'git push origin --branches'):
            self.assertEqual(self.decide(command), 'deny', command)
        git(self.repo, 'remote', 'add', 'fork', 'https://github.com/someone/repo.git')
        self.assertEqual(self.decide('git push fork feature:main'), 'allow')
        git(self.repo, 'config', 'remote.origin.pushurl', '/tmp/backup.git')
        self.assertEqual(self.decide('git push origin feature:main'), 'allow')

    def test_the_default_branch_comes_from_github_when_unrecorded(self):
        git(self.repo, 'remote', 'set-head', 'origin', '--delete')
        self.assertEqual(self.decide('git push origin feature:main'), 'deny')

    def test_an_unknown_target_passes(self):
        gh = Path(self.env['PATH'].split(':', 1)[0]) / 'gh'
        gh.write_text('#!/bin/sh\nexit 1\n')
        for command in ('gh pr ready 12', 'gh run rerun 999'):
            self.assertEqual(self.decide(command), 'allow', command)

    def test_slow_lookups_stay_within_the_hook_time_limit(self):
        gh = Path(self.env['PATH'].split(':', 1)[0]) / 'gh'
        gh.write_text('#!/bin/sh\nsleep 20\n')
        started = time.monotonic()
        self.assertEqual(self.decide('git push origin feature:a feature:b feature:c'), 'allow')
        self.assertLess(time.monotonic() - started, 9)

    def test_codex_names_the_checkout_of_a_command_that_could_start_ci(self):
        self.release()
        with tempfile.TemporaryDirectory() as session:
            for command in ('git push origin feature:main', 'gh pr ready', 'gh workflow run ci.yml'):
                self.assertEqual(codex_decide(command, session), 'deny', command)
            for command in ('cd . && git push origin feature:main', 'git -C . push origin main',
                            f'git -C {self.repo} status && git push origin main',
                            'cd sub && gh pr ready'):
                self.assertEqual(codex_decide(command, session), 'deny', command)
            self.assertEqual(codex_decide(f'git -C {self.repo} push origin feature:main', session),
                             'allow')
            self.assertEqual(codex_decide('git status', session), 'allow')
            self.assertEqual(codex_decide('gh pr view', session), 'allow')
        self.assertEqual(codex_decide(f'cd {self.repo} && git push origin feature:main',
                                      self.repo), 'allow')

    def test_a_checkout_without_workflows_passes(self):
        git(self.repo, 'rm', '-rq', '.github')
        git(self.repo, '-c', 'user.name=t', '-c', 'user.email=t@t', 'commit', '-qm', 'no ci')
        for command in ('git push origin HEAD:main', 'gh pr ready'):
            self.assertEqual(self.decide(command), 'allow', command)


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
        for command in ('ps -Ao pid,rss,comm',
                        'ps -Ao pid,rss,comm | sort -k2 -n',
                        'ps -p 123 -o pid,comm',
                        'ps -o pid= -p 123',
                        'ps -o stat= -p 123',
                        'ps -Ao pid,ppid,etime,comm',
                        'ps -Ao pid,ucomm',
                        'ps -Ao pid,pcpu,pmem,comm',
                        'ps -U 501 -o pid,user,comm',
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
                        'ps -o pid,comm 123',
                        'ps -eo pid,comm',
                        'ps -u sebastian -o pid,comm',
                        'COMMAND_MODE=legacy ps -axo comm -u',
                        'ps -axeww -o pid,comm',
                        'ps -axo environ',
                        'ps -axo %a',
                        'ps -axo DefSysV',
                        'ps -axo pid,rss,comm',
                        "ps -Ao '%cpu:%a'",
                        'ps -Ao pid,%cpu,comm',
                        'PS_PERSONALITY=hpux ps -axo comm'):
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

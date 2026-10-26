#!/usr/bin/env python3
"""Read-only message, usage and digest queries against local fixtures."""
from importlib.machinery import SourceFileLoader
import importlib.util
import json
import os
from pathlib import Path
import re
import sqlite3
import subprocess
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from unittest.mock import patch
import unittest

SCRIPT = Path(__file__).resolve().parent.parent / 'bin' / 'agent-messages'
spec = importlib.util.spec_from_loader('agent_messages', SourceFileLoader('agent_messages', str(SCRIPT)))
messages = importlib.util.module_from_spec(spec)
spec.loader.exec_module(messages)


def counts(command, category):
    script = messages.executable(messages.unwrapped(command))
    return bool(re.search(messages.COMMAND_PATTERNS[category], script))


def skill_reads(command):
    return messages.skills_read(messages.unwrapped(command))


class Commands(unittest.TestCase):
    def test_codex_wrapper_is_unwrapped(self):
        self.assertTrue(counts("/bin/zsh -lc 'gh pr checks 12 --watch'", 'hand_rolled_ci_waits'))

    def test_every_wrapper_in_a_chain_counts(self):
        self.assertTrue(counts("zsh -lc 'gh run watch 1' && zsh -lc 'echo done'",
                               'hand_rolled_ci_waits'))
        self.assertTrue(counts("bash -c 'agent-run wait run' bash", 'agent-run wait'))

    def test_quoted_text_is_not_a_command(self):
        self.assertFalse(counts("echo 'agent-run start codex review'", 'agent-run start'))
        self.assertFalse(counts('printf "%s" "gh run watch 1"', 'hand_rolled_ci_waits'))

    def test_substitution_inside_double_quotes_runs(self):
        self.assertTrue(counts('echo "$(gh run watch 123)"', 'hand_rolled_ci_waits'))
        self.assertTrue(counts('x="$(agent-run wait run)"', 'agent-run wait'))

    def test_heredoc_body_is_not_a_command(self):
        self.assertFalse(counts('python3 - <<EOF\nx = "gh pr checks --watch"\nEOF',
                                'hand_rolled_ci_waits'))
        self.assertFalse(counts("cat <<'EOF' > f\nEOF explanation\ngh run watch 1\nEOF\nls",
                                'hand_rolled_ci_waits'))

    def test_command_after_a_heredoc_opener_counts(self):
        self.assertTrue(counts("cat <<'EOF'; gh run watch 123\nbody\nEOF", 'hand_rolled_ci_waits'))

    def test_apostrophe_in_a_comment_or_escape_does_not_hide_commands(self):
        self.assertTrue(counts("# don't poll\nagent-run start codex review r", 'agent-run start'))
        self.assertTrue(counts("echo it\\'s\nagent-run start codex review r", 'agent-run start'))
        self.assertFalse(counts('# agent-run start codex review r', 'agent-run start'))

    def test_herestring_or_quoted_heredoc_marker_hides_nothing(self):
        self.assertTrue(counts('cat <<< "hello"\ngh run watch 1', 'hand_rolled_ci_waits'))
        self.assertTrue(counts("echo '<<EOF'\ngh run watch 1", 'hand_rolled_ci_waits'))

    def test_loop_around_gh_counts(self):
        self.assertTrue(counts('until gh pr checks 3; do sleep 30; done', 'hand_rolled_ci_waits'))


class SkillReads(unittest.TestCase):
    def test_reading_a_skill_file_counts(self):
        self.assertEqual(skill_reads("/bin/zsh -lc 'cat /Users/s/.codex/skills/delegate/SKILL.md'"),
                         {'delegate'})
        self.assertEqual(skill_reads("sed -n 1,80p ~/.codex/skills/.system/openai-docs/SKILL.md"),
                         {'openai-docs'})

    def test_every_file_one_command_reads_counts(self):
        self.assertEqual(skill_reads('cat a/skills/delegate/SKILL.md b/skills/research/SKILL.md'),
                         {'delegate', 'research'})

    def test_quoted_path_and_silenced_errors_still_count(self):
        self.assertEqual(skill_reads('cat "/Users/s/.codex/skills/ship/SKILL.md" 2>/dev/null'), {'ship'})

    def test_comment_quoted_example_or_write_does_not_count(self):
        self.assertEqual(skill_reads('# cat ~/.codex/skills/delegate/SKILL.md'), set())
        self.assertEqual(skill_reads("echo 'cat ~/.codex/skills/delegate/SKILL.md'"), set())
        self.assertEqual(skill_reads('cat > ~/.codex/skills/delegate/SKILL.md <<EOF\nx\nEOF'), set())

    def test_mentioning_a_skill_path_does_not_count(self):
        self.assertEqual(skill_reads('echo ~/.codex/skills/delegate/SKILL.md'), set())
        self.assertEqual(skill_reads('test -f ~/.codex/skills/delegate/SKILL.md'), set())
        self.assertEqual(skill_reads('cat > f <<EOF\nskills/delegate/SKILL.md\nEOF'), set())


class Usage(unittest.TestCase):
    WINDOW = ('2026-10-01T00:00:00Z', '2026-11-01T00:00:00Z')

    def database(self):
        db = sqlite3.connect(':memory:')
        db.executescript("""
            CREATE TABLE orchestration_v2_projection_messages (
                message_id TEXT, thread_id TEXT, role TEXT, created_at TEXT, payload_json TEXT);
            CREATE TABLE orchestration_v2_projection_turn_items (
                thread_id TEXT, type TEXT, status TEXT, updated_at TEXT, payload_json TEXT);
            CREATE TABLE orchestration_v2_projection_threads (
                thread_id TEXT, default_provider TEXT, title TEXT, project_id TEXT);
            CREATE TABLE projection_projects (project_id TEXT, title TEXT);
            INSERT INTO orchestration_v2_projection_threads VALUES ('t1', 'codex', 'T', NULL);
        """)
        return db

    def add_message(self, db, message_id, source, payload_id=None):
        payload = {'createdBy': 'user', 'creationSource': source, 'id': payload_id or message_id, 'text': 'x'}
        db.execute("INSERT INTO orchestration_v2_projection_messages VALUES (?, 't1', 'user', ?, ?)",
                   (message_id, '2026-10-20T10:00:00Z', json.dumps(payload)))

    def test_question_tool_answers_count_as_his_messages(self):
        db = self.database()
        self.add_message(db, 'm1', 'web')
        self.add_message(db, 'm2', 'server', 'async-answer:runtime-request:x')
        self.add_message(db, 'm3', 'server', 'notification:x')
        self.assertEqual(messages.usage(db, self.WINDOW)['sebastian_messages'], 2)
        self.assertEqual(len(list(messages.messages(db, self.WINDOW))), 2)

    def test_window_is_printed_in_stockholm_time_across_a_dst_change(self):
        window = ('2026-10-19T12:51:36Z', '2026-10-26T12:51:36Z')
        self.assertEqual(messages.usage(self.database(), window)['window'],
                         {'since': '2026-10-19T14:51:36+02:00', 'until': '2026-10-26T13:51:36+01:00'})

    def test_failed_skill_read_does_not_count(self):
        db = self.database()
        for status in ('completed', 'failed'):
            db.execute("INSERT INTO orchestration_v2_projection_turn_items VALUES ('t1', 'command_execution', ?, ?, ?)",
                       (status, '2026-10-20T10:00:00Z',
                        json.dumps({'input': 'cat ~/.codex/skills/ship/SKILL.md'})))
        self.assertEqual(messages.usage(db, self.WINDOW)['skill_loads']['codex'], {'ship': 1})


class Digest(unittest.TestCase):
    NOW = datetime(2026, 10, 26, 12, tzinfo=timezone.utc)
    WINDOW = ('2026-10-24T12:00:00Z', '2026-10-26T12:00:00Z')

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = (Path(self.temp.name) / 'project').resolve()
        self.root.mkdir()
        self.db = sqlite3.connect(':memory:')
        self.addCleanup(self.db.close)
        self.db.executescript('''
            CREATE TABLE projection_projects (
                project_id TEXT, title TEXT, workspace_root TEXT, deleted_at TEXT);
            CREATE TABLE orchestration_v2_projection_threads (
                thread_id TEXT, title TEXT, project_id TEXT, archived_at TEXT,
                deleted_at TEXT, payload_json TEXT);
            CREATE TABLE orchestration_v2_projection_runs (
                run_id TEXT, thread_id TEXT, status TEXT, requested_at TEXT, completed_at TEXT);
            CREATE TABLE orchestration_v2_projection_runtime_requests (
                runtime_request_id TEXT, thread_id TEXT, node_id TEXT, kind TEXT,
                status TEXT, created_at TEXT, payload_json TEXT);
            CREATE TABLE orchestration_v2_projection_turn_items (
                node_id TEXT, thread_id TEXT, type TEXT, ordinal INTEGER, payload_json TEXT);
            CREATE TABLE orchestration_v2_projection_subagents (
                subagent_id TEXT, status TEXT, started_at TEXT);
            CREATE TABLE projection_thread_pull_requests (
                thread_id TEXT, url TEXT, snapshot_json TEXT);
        ''')
        self.db.execute('INSERT INTO projection_projects VALUES (?, ?, ?, NULL)',
                        ('p1', 'Project', str(self.root)))
        self.thread('t1')
        self.github = {}

    def thread(self, tid, archived=None, deleted=None, **payload):
        self.db.execute('INSERT INTO orchestration_v2_projection_threads VALUES (?, ?, ?, ?, ?, ?)',
                        (tid, 'Thread ' + tid, 'p1', archived, deleted, json.dumps(payload)))

    def effort(self, name, status='active', age=1, root=None, done_status='open', extra='', checkout=None):
        root = root or self.root
        path = root / '.scratch' / name / 'effort.md'
        path.parent.mkdir(parents=True)
        path.write_text(f'''---
status: {status}
session: session-1
checkout: {checkout or root}
---
# {name}

## Done when
| # | Item | Check on the real target | Status | Evidence |
|---|---|---|---|---|
| 1 | Verify the result | Readback | {done_status} | |

{extra}
''')
        modified = (self.NOW - timedelta(hours=age)).timestamp()
        os.utime(path, (modified, modified))
        return path

    def run_digest(self, window=None):
        fixed = self.NOW

        class Clock(datetime):
            @classmethod
            def now(cls, tz=None):
                return fixed.astimezone(tz)

        # GitHub's live view of a pull request stored as open; {} keeps the
        # snapshot, None is a failed `gh` call.
        github = lambda url: self.github.get(url, {})
        with patch.object(messages, 'datetime', Clock), \
                patch.object(messages, 'github_pull_request', github):
            return messages.digest(self.db, window or self.WINDOW)

    def pr(self, state='open', draft=False, merged=None, tid='t1', number=1):
        url = f'https://github.com/example/repo/pull/{number}'
        self.db.execute('INSERT INTO projection_thread_pull_requests VALUES (?, ?, ?)',
                        (tid, url, json.dumps({'state': state, 'isDraft': draft, 'title': 'PR title',
                                              'mergedAt': merged, 'syncedAt': '2026-10-26T11:00:00Z'})))
        return url

    def run_row(self, rid, tid='t1', status='running', completed=None):
        self.db.execute('INSERT INTO orchestration_v2_projection_runs VALUES (?, ?, ?, ?, ?)',
                        (rid, tid, status, '2026-10-24T00:00:00Z', completed))

    def test_landed_events_use_half_open_window_and_stockholm_offsets(self):
        done = self.effort('done', status='done')
        self.effort('too-old', status='done', age=49)
        self.effort('at-until', status='done', age=0)
        self.effort('at-since', status='done', age=48)
        self.pr(state='merged', merged=self.WINDOW[0])
        self.pr(state='merged', merged=self.WINDOW[1], number=2)
        self.pr(state='merged', merged='2026-10-23T12:00:00Z', number=3)
        out = self.run_digest()
        self.assertEqual(out['window'], {'since': '2026-10-24T14:00:00+02:00',
                                         'until': '2026-10-26T13:00:00+01:00'})
        self.assertEqual(len(out['landed']), 3)
        efforts = [r for r in out['landed'] if r['type'] == 'effort']
        self.assertEqual({r['effort_title'] for r in efforts}, {'done', 'at-since'})
        self.assertIn(str(done), [r['effort_path'] for r in efforts])
        self.assertTrue(all(r['completion_signal'] == 'file_mtime' for r in efforts))
        pr = next(r for r in out['landed'] if r['type'] == 'pull_request')
        self.assertEqual(pr['thread_title'], 'Thread t1')
        self.assertEqual(pr['merged_at'], '2026-10-24T14:00:00+02:00')

    def test_pending_requests_read_only_question_text_and_age(self):
        for request, status, kind in [('q', 'pending', 'user_input'), ('a', 'pending', 'approval'),
                                       ('old', 'resolved', 'user_input')]:
            self.db.execute('INSERT INTO orchestration_v2_projection_runtime_requests VALUES '
                            "(?, 't1', ?, ?, ?, '2026-10-26T10:00:00Z', ?)",
                            (request, request, kind, status, json.dumps({'answers': {'x': 'never emit answers'}})))
        self.db.execute('INSERT INTO orchestration_v2_projection_turn_items VALUES '
                        "('q', 't1', 'user_input_request', 1, ?)",
                        (json.dumps({'questions': [{'question': 'Which format?', 'options': [{'label': 'hidden'}]}],
                                     'questionAnswer': {'text': 'do not emit'}, 'input': 'never emit a command'}),))
        out = self.run_digest()
        rows = out['waiting_on_sebastian']
        self.assertEqual(len(rows), 2)
        question = next(r for r in rows if r['request_id'] == 'q')
        self.assertEqual(question['questions'], ['Which format?'])
        self.assertEqual(question['age_seconds'], 7200)
        self.assertEqual(question['project_title'], 'Project')
        approval = next(r for r in rows if r['request_id'] == 'a')
        self.assertEqual(approval['kind'], 'approval')
        self.assertEqual(approval['questions'], [])
        self.assertNotIn('never emit', json.dumps(out))
        self.assertNotIn('hidden', json.dumps(out))

    def test_blocked_efforts_and_open_pr_handovers(self):
        path = self.effort('blocked', status='blocked', extra='## Blockers\n\nNeed a choice.\n\n## Next\nPrivate body')
        url = self.pr()
        self.pr(draft=True, number=2)
        self.pr(state='closed', number=3)
        self.thread('busy')
        self.run_row('active', 'busy')
        self.pr(tid='busy', number=4)
        self.thread('status-running', status='running')
        self.pr(tid='status-running', number=5)
        self.thread('deleted', deleted='2026-10-25T00:00:00Z')
        self.pr(tid='deleted', number=6)
        out = self.run_digest()
        self.assertEqual(len(out['waiting_on_sebastian']), 2)
        effort = next(r for r in out['waiting_on_sebastian'] if r['type'] == 'effort')
        self.assertEqual(effort['effort_path'], str(path))
        self.assertEqual(effort['blockers'], 'Need a choice.')
        self.assertTrue(effort['blockers_section_present'])
        self.assertEqual(next(r['url'] for r in out['waiting_on_sebastian'] if r['type'] == 'pull_request'), url)
        self.assertNotIn('Private body', json.dumps(out))

    def test_open_snapshot_is_checked_against_github(self):
        merged = self.pr(number=1)
        self.github[merged] = {'state': 'MERGED', 'isDraft': False,
                               'mergedAt': '2026-10-25T09:00:00Z', 'title': 'Live title'}
        unreachable = self.pr(number=2)
        self.github[unreachable] = None
        out = self.run_digest()
        landed = next(r for r in out['landed'] if r['type'] == 'pull_request')
        self.assertEqual((landed['url'], landed['state_source'], landed['pr_title']),
                         (merged, 'github', 'Live title'))
        waiting = [r for r in out['waiting_on_sebastian'] if r['type'] == 'pull_request']
        self.assertEqual([(r['url'], r['state_source']) for r in waiting], [(unreachable, 'snapshot')])
        self.assertEqual([e['url'] for e in out['errors'] if e.get('operation') == 'refresh_pull_request'],
                         [unreachable])

    def test_late_milestones_stalled_efforts_and_failed_runs(self):
        extra = '''## Milestones
| Milestone | Due (Stockholm) | State |
|---|---|---|
| Old \\| milestone | 2026-10-25 02:30 | open |
| Future | 2026-10-27 10:00 | open |
| Finished | 2026-10-24 10:00 | met |
'''
        path = self.effort('stale', age=7, extra=extra)
        self.effort('six-hours-exactly', age=6)
        self.effort('fresh', age=1)
        self.effort('passed', age=7, done_status='pass')
        self.effort('blocked-item', age=7, done_status='blocked')
        self.run_row('failed', status='failed', completed='2026-10-25T12:00:00Z')
        self.run_row('outside', status='failed', completed=self.WINDOW[1])
        self.run_row('cancelled', status='cancelled', completed='2026-10-25T12:00:00Z')
        out = self.run_digest()
        self.assertCountEqual([r['type'] for r in out['late']],
                              ['overdue_milestone', 'stalled_effort', 'failed_run'])
        stalled = next(r for r in out['late'] if r['type'] == 'stalled_effort')
        self.assertEqual(stalled['effort_path'], str(path))
        self.assertEqual(stalled['unchanged_seconds'], 7 * 3600)
        self.assertEqual(stalled['open_items'], ['#1 Verify the result'])
        milestone = next(r for r in out['late'] if r['type'] == 'overdue_milestone')
        self.assertEqual(milestone['milestone'], 'Old \\| milestone')
        self.assertEqual(milestone['due'], '2026-10-25T02:30:00+02:00')
        self.assertEqual(out['running']['active_efforts'], 5)

    def test_legacy_milestone_headers_and_missing_blocker_section(self):
        self.effort('legacy', status='blocked', extra='''## Milestones
| Due | Milestone | Status |
|---|---|---|
| 2026-10-25 10:00 | Old | open |
''')
        out = self.run_digest()
        self.assertEqual(len(out['late']), 1)
        self.assertEqual(out['waiting_on_sebastian'][0]['blockers'], '')
        self.assertFalse(out['waiting_on_sebastian'][0]['blockers_section_present'])

    def test_ended_t3_tasks_match_full_id_or_latest_client_request(self):
        task_id = 'node:delegated-task:command%3Amcp%3Athread%3Adelegate-task%3Aclient'
        rows = [(task_id, 'completed', '2026-10-26T10:00:00Z'),
                ('node:delegated-task:old-delegate-task%3Aclient', 'running', '2026-10-25T10:00:00Z'),
                ('node:delegated-task:x-delegate-task%3Abusy', 'running', '2026-10-26T10:00:00Z')]
        self.db.executemany('INSERT INTO orchestration_v2_projection_subagents VALUES (?, ?, ?)', rows)
        self.effort('tasks', extra=f'''## Running tasks
| Task | Runtime, model, effort | Handle | Worktree / branch | State |
|---|---|---|---|---|
| By ID | T3 Codex | {task_id} | main | running |
| By client | T3 Claude | client | main | running |
| Mixed | T3 | client busy | main | running |
| Unknown | T3 | unknown schedule-1 | main | running |
| Finished row | T3 | client | main | done |
| Local | shell | client | main | running |
''')
        out = self.run_digest()
        self.assertEqual([r['task'] for r in out['late']], ['By ID', 'By client'])
        self.assertTrue(all(r['ended_tasks'] == [{'task_id': task_id, 'status': 'completed'}]
                            for r in out['late']))

    def test_running_counts_distinct_threads_with_nonterminal_runs(self):
        self.effort('active')
        self.effort('done', status='done')
        self.thread('other')
        self.run_row('r1')
        self.run_row('r2')
        self.run_row('queued', 'other', 'queued')
        self.run_row('finished', status='completed', completed='2026-10-25T12:00:00Z')
        self.assertEqual(self.run_digest()['running'], {'active_efforts': 1, 'threads_with_active_run': 2})

    def test_discovers_worktrees_deduplicates_roots_and_skips_copied_efforts(self):
        def git(*args):
            subprocess.run(['git', '-C', str(self.root), *args], check=True, capture_output=True)

        git('init')
        git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
            '-c', 'core.hooksPath=/dev/null', 'commit', '--allow-empty', '-m', 'fixture')
        linked = (Path(self.temp.name) / 'linked checkout').resolve()
        git('worktree', 'add', '--detach', str(linked), 'HEAD')
        self.effort('original')
        self.effort('linked', root=linked)
        self.effort('copied', root=linked, checkout=self.root)
        self.db.execute('INSERT INTO projection_projects VALUES (?, ?, ?, NULL)', ('p2', 'Duplicate', str(linked)))
        out = self.run_digest()
        self.assertEqual(out['running']['active_efforts'], 2)
        self.assertEqual(out['errors'], [])

    def test_unreadable_effort_is_skipped_and_reported(self):
        path = self.effort('unreadable')
        self.effort('readable')
        original = Path.read_text

        def read(file, *args, **kwargs):
            if file == path:
                raise PermissionError('sensitive exception text must not be printed')
            return original(file, *args, **kwargs)

        with patch.object(Path, 'read_text', read):
            out = self.run_digest()
        self.assertEqual(out['running']['active_efforts'], 1)
        self.assertEqual(out['errors'], [{'effort_path': str(path), 'operation': 'read_effort',
                                          'error': 'PermissionError'}])

    def test_reports_invalid_json_and_dates_without_exposing_payloads(self):
        self.effort('bad-date', extra='''## Milestones
| Due (Stockholm) | Milestone | State |
|---|---|---|
| tomorrow maybe | Bad | open |
''')
        self.db.execute("INSERT INTO projection_thread_pull_requests VALUES ('t1', 'https://example.invalid/pr', 'bad')")
        out = self.run_digest()
        self.assertCountEqual([e['error'] for e in out['errors']], ['invalid JSON object', 'invalid timestamp'])

    def test_redacts_credentials_but_preserves_encoded_link_ids(self):
        tid = 'thread:delegated-task:command%3Amcp%3Ac5d4a596-3cbd-44ca-a2bc-795881022cce%3Adelegate-task%3Aclient'
        self.thread(tid)
        token = 'ghp_' + 'SyntheticFixtureOnly1234567890'
        self.db.execute('INSERT INTO orchestration_v2_projection_runtime_requests VALUES '
                        "('q', ?, 'n', 'user_input', 'pending', '2026-10-26T10:00:00Z', ?)",
                        (tid, json.dumps({'question': 'Use token=' + token + '?'})))
        self.effort('redact', status='blocked', extra='## Blockers\npassword=FixtureOnly\n'
                    'Bearer SyntheticFixtureOnly\n' + '0123456789abcdef' * 3 + '\n'
                    '"GITHUB_TOKEN": "FixtureOnly with spaces"\n'
                    'postgres://user:FixtureOnly@localhost/db\n'
                    '-----BEGIN PRIVATE KEY-----\nfixture\n-----END PRIVATE KEY-----')
        out = self.run_digest()
        text = json.dumps(out)
        self.assertNotIn('FixtureOnly', text)
        self.assertNotIn('0123456789abcdef', text)
        self.assertNotIn('PRIVATE KEY', text)
        self.assertEqual(out['waiting_on_sebastian'][0]['thread_id'], tid)

    def test_cli_default_and_independent_bounds(self):
        with patch.object(sys, 'argv', ['agent-messages', 'digest']):
            command, window = messages.arguments()
        self.assertEqual(command, 'digest')
        self.assertEqual(messages.iso_time(window[1]) - messages.iso_time(window[0]), timedelta(hours=24))
        with patch.object(sys, 'argv', ['agent-messages', 'digest', '--until', self.WINDOW[1]]):
            _, window = messages.arguments()
        self.assertEqual(window, ('2026-10-25T12:00:00+00:00', '2026-10-26T12:00:00+00:00'))
        with patch.object(sys, 'argv', ['agent-messages', 'digest', '--since', self.WINDOW[0]]):
            _, window = messages.arguments()
        self.assertEqual(window[0], '2026-10-24T12:00:00+00:00')

    def test_main_emits_one_object_and_keeps_a_read_only_snapshot(self):
        path = Path(self.temp.name) / 'fixture.sqlite'
        self.db.commit()
        with sqlite3.connect(path) as db:
            self.db.backup(db)
        connect = sqlite3.connect
        statements = []

        def opened(database, **kwargs):
            self.assertEqual(database, path.as_uri() + '?mode=ro')
            self.assertTrue(kwargs['uri'])
            db = connect(database, **kwargs)
            db.set_trace_callback(statements.append)
            with self.assertRaises(sqlite3.OperationalError):
                db.execute('CREATE TABLE forbidden (x)')
            return db

        with patch.object(messages, 'DATABASE', path), patch.object(sys, 'argv', ['agent-messages', 'digest']), \
                patch.object(messages.sqlite3, 'connect', opened), \
                patch('builtins.print') as output:
            self.assertEqual(messages.main(), 0)
        output.assert_called_once()
        self.assertEqual(statements.count('BEGIN'), 1)
        self.assertEqual(set(json.loads(output.call_args.args[0])),
                         {'window', 'state_observed_at', 'landed', 'waiting_on_sebastian', 'late', 'running', 'errors'})


if __name__ == '__main__':
    unittest.main()

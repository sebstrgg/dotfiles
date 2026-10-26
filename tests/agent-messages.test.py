#!/usr/bin/env python3
"""Tests for how agent-messages reads shell commands."""
from importlib.machinery import SourceFileLoader
import importlib.util
from pathlib import Path
import re
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

    def test_mentioning_a_skill_path_does_not_count(self):
        self.assertEqual(skill_reads('echo ~/.codex/skills/delegate/SKILL.md'), set())
        self.assertEqual(skill_reads('test -f ~/.codex/skills/delegate/SKILL.md'), set())
        self.assertEqual(skill_reads('cat > f <<EOF\nskills/delegate/SKILL.md\nEOF'), set())


if __name__ == '__main__':
    unittest.main()

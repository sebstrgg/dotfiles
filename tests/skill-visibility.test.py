#!/usr/bin/env python3
"""Tests for how skill-visibility hides a skill from both runtimes."""
from importlib.machinery import SourceFileLoader
import importlib.util
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parent.parent / 'bin' / 'skill-visibility'
spec = importlib.util.spec_from_loader('skill_visibility', SourceFileLoader('skill_visibility', str(SCRIPT)))
visibility = importlib.util.module_from_spec(spec)
spec.loader.exec_module(visibility)


def make_skill(root, policy=None):
    skill = Path(root) / 'tdd'
    (skill / 'agents').mkdir(parents=True)
    (skill / 'SKILL.md').write_text('---\nname: tdd\ndescription: Test first.\n---\n\n# TDD\n\n---\nnot front matter\n')
    if policy is not None:
        (skill / 'agents' / 'openai.yaml').write_text(policy)
    return skill


class Hide(unittest.TestCase):
    def test_hides_in_both_runtimes_and_keeps_the_interface(self):
        with tempfile.TemporaryDirectory() as root:
            skill = make_skill(root, 'interface:\n  display_name: "TDD"\n')
            self.assertTrue(visibility.hide(skill))
            self.assertTrue(visibility.hidden_from('claude', skill))
            self.assertTrue(visibility.hidden_from('codex', skill))
            self.assertIn('display_name: "TDD"', (skill / 'agents' / 'openai.yaml').read_text())
            self.assertTrue((skill / 'SKILL.md').read_text().endswith('# TDD\n\n---\nnot front matter\n'))

    def test_second_run_changes_nothing(self):
        with tempfile.TemporaryDirectory() as root:
            skill = make_skill(root)
            visibility.hide(skill)
            before = (skill / 'SKILL.md').read_text(), (skill / 'agents' / 'openai.yaml').read_text()
            self.assertFalse(visibility.hide(skill))
            self.assertEqual(before, ((skill / 'SKILL.md').read_text(), (skill / 'agents' / 'openai.yaml').read_text()))

    def test_flips_an_explicit_allow(self):
        with tempfile.TemporaryDirectory() as root:
            skill = make_skill(root, 'policy:\n  allow_implicit_invocation: true\n')
            visibility.hide(skill)
            self.assertEqual((skill / 'agents' / 'openai.yaml').read_text(), 'policy:\n  allow_implicit_invocation: false\n')

    def test_body_text_does_not_count_as_hidden(self):
        with tempfile.TemporaryDirectory() as root:
            skill = make_skill(root)
            (skill / 'SKILL.md').write_text('---\nname: tdd\n---\n\ndisable-model-invocation: true\n')
            self.assertFalse(visibility.hidden_from('claude', skill))


if __name__ == '__main__':
    unittest.main()

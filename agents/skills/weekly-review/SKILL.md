---
name: weekly-review
description: Weekly measurement of how much of Sebastian's attention agents still need, with one improvement proposal. Use when the weekly schedule fires or he asks for the weekly review.
disable-model-invocation: true
---

# Weekly review

Measure whether agents carry more work with less of Sebastian's attention,
find the pattern that costs him most, and propose one fix. Read-only except
the report and doc-only clean-up. Budget: about 30 minutes.

## 1. Measure

- `~/dotfiles/bin/agent-messages usage --days 7` gives counts: his messages,
  T3 tool use, skill loads per runtime (Claude `Skill` calls, Codex reads of
  `SKILL.md`), question-tool use, delegation path, hand-rolled CI waits,
  scheduled wakes and delegated briefs. Compare with the baseline's
  `agent-messages` line.
- `~/dotfiles/bin/agent-messages messages --days 7` gives his messages with
  the agent's preceding reply. Classify each, from his words plus that reply:
  - `new-task`: a new request or a follow-up not caused by an agent mistake.
  - `answer`: answers a question or grants an approval the agent asked for.
    Also flag `needless-ask` when the agent asked about something the global
    instructions let it decide (his reply is "your rec", "use your
    judgment", "just do it").
  - `correction`: the agent got something wrong.
  - `process`: he had to enforce how work is done (verify it, use the
    browser, commit, use a tool, follow a rule).
  - `nudge`: "continue", "status?", "why did you stop".
  - `question` and `other`.
  For corrections, process and nudges, add a theme: wrong-approach,
  wrong-assumption, ignored-instruction, ui-quality, false-done,
  skipped-verification, stopped-early, over-process, tooling-misuse,
  communication, scope-creep. Over ~150 messages, split them across two
  Sonnet subagents with this rubric and merge their counts.
- Rates, as shares of his messages: steering (correction + process + nudge),
  corrections, process, nudges, needless asks; and corrections per new task.
- Efforts delivered with a passing `verify`, from the week's effort files and
  git history. Message counts stand in for attention; they are not minutes.

## 2. Compare and diagnose

- Put each rate next to last week's (the newest earlier report) and the
  baseline in `2026-10-26-baseline.md`. A change of a few points on a few
  hundred messages is noise; say so.
- Check that the skills are used where they should be: are `ship`,
  `prove-it`, `delegate` and `babysit-pr` loaded in threads that shipped,
  proved or reviewed changes? Is delegation going through `delegate_task`, PR
  waits through `watch_pull_request`, blocking questions through the question
  tool? Do posted PR comments open with the signature line from
  `babysit-pr`? `~/dotfiles/bin/skill-visibility check` lists any skill that
  loads on its own outside the allowlist.
- Take the largest theme. Read two or three of its threads and ask what in
  the agent's context pointed it the wrong way (`retro`).

## 3. One improvement

Propose one change, highest rung first: remove the failure in code or
architecture; else a check, lint, test or tool; else a skill edit; else one
global rule that replaces an existing one. Give the evidence and the expected
effect on next week's numbers. Rule and skill changes wait for Sebastian:
ask through the question tool with your recommendation.

## 4. Stale files

In `~/dotfiles` and each repository under `~/code` with commits this week:
effort files marked `done` or untouched for 14 days, plan, spec and ticket
files for finished work, and docs that contradict the code. Fix doc-only
staleness (check against the code, commit, merge); list the rest.

## Report

Save it as `~/dotfiles/.scratch/weekly-review/<YYYY-MM-DD>.md`, keep the
eight newest plus the baseline. In the thread: a small table of this week,
last week and baseline, the top theme with two examples, the proposal, the
clean-up done. When nothing changed and nothing is needed, one line.

---
name: weekly-review
description: Weekly review of agent autonomy and project hygiene.
disable-model-invocation: true
---

# Weekly review

Measure whether agents carry more work with less of Sebastian's attention, keep
projects free of stale working files, and propose at most one improvement.
Budget: about 20 minutes. Report only what is new or needs Sebastian.

## 1. Where Sebastian's attention went

Run `~/dotfiles/bin/agent-messages --days 7`. Classify each message:

- **Valuable**: direction, priorities, taste, a genuine decision, new information.
- **Avoidable**: approving the agent's own recommendation, "continue" or
  status and ETA pings, relaying between sessions, pasting starter prompts,
  reminding agents of an existing rule.
- **Rescue**: reporting that something declared done does not work, or
  correcting a wrong result.

Count per category, and count efforts delivered with a passing `verify` (from
the week's effort files and git history). Compare with the previous report.
Message counts stand in for attention; they are not minutes.

## 2. Stale working files

In each repository under `~/code` with commits this week:

- effort files untouched for 14 days or marked `done`;
- plan, spec and ticket files for finished work;
- docs that contradict the code.

Fix doc-only staleness directly: update or delete, check against the code,
commit, and merge per delivery. Anything beyond docs becomes a proposal.

## 3. One improvement

Find the most frequent avoidable or rescue pattern. Apply `retro` to two or three
of its examples and propose one change to the environment (a check, a tool, a
template, or one rule replacing an existing one) with its evidence. Rule
changes wait for Sebastian's approval.

## Report

Counts with last week's next to them, the clean-up done, the one proposal, and
anything that needs Sebastian. When nothing changed and nothing is needed, say
so in one line.

Save it as `~/dotfiles/.scratch/weekly-review/<YYYY-MM-DD>.md`; last week's
report is the newest file there. Keep the four newest.

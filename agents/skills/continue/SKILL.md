---
name: continue
description: Continue an effort in a fresh session. Use when an effort must move to a new session (end of an effort with follow-up work, switching runtime, degraded context) or when Sebastian asks for a handoff or continuation.
---

# Continue

Compaction keeps a run going in the same session; prefer it. Use this only when
a fresh session is needed.

## 1. Bring the effort file current

The fresh session reads only the effort file and the files it links. Make sure
it holds the brief with every approval, the "done when" table with honest
statuses, decisions with reasons, running tasks with resume handles, and the
next step. Link specs, tickets and commits instead of copying them.

## 2. Start the continuation yourself

- Write the prompt below to `.scratch/<effort>/runs/continue-<n>/prompt.md`
  and, from the effort's checkout, run
  `~/dotfiles/bin/agent-run start <codex|claude> continue <that folder>`. It
  pins model and effort per `delegate` (`--model` and `--effort` change them)
  and gives the continuation full access, so it can commit and verify.

Prompt, at most 10 lines: the effort file path, "run
`~/dotfiles/bin/effort-gate claim <file>` and resume from Next", and any
rule specific to this effort that the global and repository instructions do
not carry. Do not restate global instructions.

Print the prompt for Sebastian only when he asks for it or when you cannot
start a session yourself.

## 3. Close this session

Finish or cancel this session's background jobs, record the new session's
handle in the effort file, and report where the work continues.

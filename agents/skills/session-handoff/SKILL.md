---
name: session-handoff
description: Hand work to a fresh session. Use when Sebastian asks for a handoff, starter prompt, continuation prompt or fresh session; when the next useful event lies beyond the prompt-cache lifetime; or at a phase boundary of a long session.
---

# Session handoff

The ledger carries the state; the starter prompt only points at it. A fresh agent with the
starter prompt and the files it names resumes without asking Sebastian anything.

## 1. Bring the ledger current

Use the effort's existing ledger (a `RESUME HERE` block, tracker or state file the project
already keeps); create `.scratch/<effort>/ledger.md` only when none exists. It records:

- the goal and the checkable condition that means done;
- every live task: runtime, resume handle (agent ID or Codex thread), worktree/branch,
  state, next step;
- decisions in force and approvals granted, each with where it was given;
- what is still unproven, and what the last run tried;
- cleanup state: worktrees, branches, containers and background jobs, each removed or
  named as handed off.

Done when every live task and every approval the next session relies on is in the ledger,
and the ledger links issues, specs and commits instead of copying them.

## 2. Print the starter prompt in chat

One fenced block of at most 15 lines, in this order:

1. `/goal <done condition>` when the run should continue until a checkable condition holds;
   otherwise a one-line goal.
2. Read first: the ledger path, then the issues or specs it names.
3. Authority: what is approved (push, merge, deploy, live targets) and what is not.
4. Orchestrator and worker model and effort, per the global routing rules.
5. Rules specific to this effort that the global and repository instructions do not
   already carry.
6. The next step.

Do not restate global or repository instructions; the fresh session loads them.

## 3. Close this session

Finish or cancel this session's background jobs, then report the ledger path and the
starter prompt.

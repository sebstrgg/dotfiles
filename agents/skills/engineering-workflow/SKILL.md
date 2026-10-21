---
name: engineering-workflow
description: Sebastian's path from request to verified result. Use at the start of any engineering task (feature, fix, new project, infrastructure change, review, diagnosis) and when scope, evidence or phase changes.
---

# Engineering workflow

One path for every change: intake, plan, build, prove and review, deliver,
verify, close. The
global instructions own authority and the meaning of done; this skill owns the
sequence. Questions, reviews and diagnosis stop after intake with an answer
unless a change is requested.

## 1. Intake

- Gather context: repository instructions, docs and ADRs, and any active
  `.scratch/*/effort.md` for this work. Taking an effort over (resuming or
  continuing it): run `~/dotfiles/bin/effort-gate claim <file>` and continue
  from its next step. A delegated agent works its brief and leaves the file to
  its owner.
- A quick change (global instructions, "How work runs") skips the effort
  file, planning and the fresh verifier: make it, check it once on the real
  target and report the evidence.
- Otherwise create the effort file with
  `~/dotfiles/bin/effort-gate new <effort>`, the agent setup's own tool, which
  writes only inside this checkout. It copies
  [the template](templates/effort.md) to `.scratch/<effort>/effort.md`,
  records this checkout and session as its owner and keeps `.scratch/` out of
  git.
  Fill in its brief and "done when" list now, before any product edit or
  background job, keeping the template's structure: the stop gate and
  compaction hook read only files it created or claimed.
- A clear request is the approved brief. Otherwise ask once: numbered questions,
  each with your recommendation. For a new project, or a big feature with
  unsettled intent, run `grilling` until the brief's "done when" list is
  settled.
- In Codex, when `create_goal` is available, also set a goal whose objective
  is the outcome.

Intake is complete when the effort file holds the outcome, "done when" items
checkable on the real target, the approvals given, and a budget.

## 2. Plan

- Small work: the effort file is the plan.
- Work spanning sessions or parallel lanes: `to-spec`, then `to-tickets` into
  `.scratch/<effort>/`, then `implement-spec` with lanes run per `delegate`.
  These and `retro` are Sebastian's commands, not callable skills: read
  `~/.agents/skills/<name>/SKILL.md` and follow it.
- Pull in on demand: `codebase-design` for a consequential structure,
  `domain-modeling` for unclear terms, `research` for an open factual
  question, `prototype` when a question needs runnable evidence.
- UI, visual design or copy: [design reference](references/design.md).
- New project or onboarding a repository: [new-project baseline](references/new-project.md).

Installed playbooks contain steps that wait for the user: confirm seams,
approve a breakdown, confirm understanding, name a fixed point. The approved
brief satisfies every one of them: decide, record the decision in the effort
file, continue. Grilling for a new project or big feature is the exception,
because it produces the brief.

## 3. Build

- Drive behaviour test-first (`tdd`) at seams you choose.
- Fix the class, not the instance: before a narrow fix, find every sibling of
  the defect and fix or report the whole set.
- A failure that resists a first look: `diagnosing-bugs`, starting from a red
  loop.
- Commit in small meaningful steps; update docs the change touches as you go.

## 4. Prove and review

Run these in order; each can still change the work, so none waits behind a slow
check:

1. Prove the change has the intended effect on the real target or real data,
   with the fastest decisive check, and record the evidence in the effort file.
2. Code where a missed bug is expensive (security, auth or secrets, persisted
   data, migrations or deletion, concurrency, paid calls, public contracts, a
   large cross-module change) gets one cross-family `code-review`. Fix
   confirmed findings and re-check once.
3. Full CI and slow suites run once, on the final change.

Infrastructure and configuration: live readback plus the affected behaviour.
Docs: compared with their source.

## 5. Deliver

Follow [delivery](references/delivery.md): branches, pull requests, merge,
deploy. Internal delivery proceeds; external actions need an approval recorded
in the effort file.

## 6. Verify

Dispatch a fresh agent to run `verify` against the "done when" list on the real
target (after deploy when the outcome lives on a deployed service), from the
other model family: from Claude, `codex exec` per `delegate`; from Codex,
`claude -p --model opus`. The effort owner dispatches it as part of the approved
workflow. Fix what fails and verify again. Verification is complete when every
item passes.

## 7. Close

- Move lasting decisions into the project's docs (ADR, README, `AGENTS.md`).
- Delete plan, spec or ticket files the work made obsolete. Set the effort
  file to `status: done` and leave it: the weekly review counts and removes it.
- Remove the worktrees, branches, containers and background jobs this work
  created.
- Report from the effort file: the outcome, the evidence (naming any item
  checked only by a substitute), decisions worth knowing, and what Sebastian
  needs to do. Each reserved action still under "Not approved" ends the report
  as a question to him with your recommendation, even when all local work is
  done.
- After substantial rework, an escaped defect or repeated steering: `retro`,
  then fix the environment (a check, a tool, or one rule) rather than adding
  prose.

## Staying on course

- The stop gate blocks the session named in `session:` from ending a turn
  while the effort file has open items; other sessions are never gated. To
  stop legitimately, set `status: blocked` with the blocker recorded, or
  `status: done` after `verify` passes.
- Waiting on a job or agent: record it under "Running tasks" with state
  `running`. Claude ends its turn and is woken when it finishes; Codex waits
  with one blocking wait on its completion. Update the row when it ends.
- Keep the effort file current whenever a decision, approval, item status or
  next step changes. After compaction it is the source of truth.

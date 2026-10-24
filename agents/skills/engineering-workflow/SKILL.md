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

- Gather context: repository instructions, docs and ADRs, the documented
  conventions of the closest existing sibling when you create a new one (host,
  service, page), and any active `.scratch/*/effort.md` for this work. Taking
  an effort over (resuming or continuing it): run
  `~/dotfiles/bin/effort-gate claim <file>` and continue from its next step. A
  delegated agent (its prompt is a brief from an orchestrator) works that brief
  and ends on its report, which is its final message: it creates no effort file
  and starts no review, verify or worker of its own; those are the
  orchestrator's.
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
- Before work runs unattended (Sebastian asleep or away), check the plan
  against what that stretch allows, before he leaves:
  - Mark every "done when" item that needs him (labels, sign-in, a decision),
    a runtime he ruled out, or more time than the stretch has. Each one is
    either cut from this stretch or becomes a blocker now, not at his return.
  - Estimate from this effort's measured pace (items or tickets done per hour
    so far), not from hope.
  - Write the stretch as `## Milestones` with local due times. The stop hook
    raises each overdue one.
  - Tell him plainly what will and will not be true when he returns. If he
    restricted runtimes and that rules out the other-family verify, record
    `verifier: <runtime>` in the front matter: a fresh run of the allowed
    family verifies.

Intake is complete when the effort file holds the outcome, "done when" items
checkable on the real target, the approvals given, and a budget. A quality the
request names (fast, optimised, secure) is a measured item; a change to
persisted state has an item that the new build starts against a copy of the
current production state.

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
- Fix the root cause (global instructions, "What matters"): before editing,
  record it under "Root cause" in the effort file, then fix the class, not the
  instance: find every sibling of the defect and fix or report the whole set.
- A failure that resists a first look: `diagnosing-bugs`, starting from a red
  loop.
- Commit in small meaningful steps; update docs the change touches as you go.

## 4. Prove, review and release

CI is the release gate, not the test loop: every session shares one CI farm,
so the work iterates on a local build and goes through CI once. Each step can
still change the work, so none waits behind a slow check:

1. Prove the change has the intended effect with the fastest decisive check,
   and record the evidence in the effort file: the real target where the change
   reaches it without a release (data, configuration, infrastructure), and a
   local build of the change against a copy of the real state where it ships
   through CI. For UI that is a visual pass of the rendered app against the
   version it replaces: passing tests only say it is time for that pass.
2. Run the CI job's fast steps (lint, format, type and repository-root checks)
   across the whole repository and every test that exercises changed code,
   locally.
3. Code where a missed bug is expensive (security, auth or secrets, persisted
   data, migrations or deletion, concurrency, paid calls, public contracts, a
   large cross-module change) gets one cross-family review
   (`~/dotfiles/bin/agent-run start <codex|claude> review`). Fix confirmed
   findings and re-check once.
4. Findings are `blocker`, `major` or `minor`. Blockers and majors from these
   steps go into the same change; minors become issues. A review that finds
   only minors passes. A change gets one review and one re-check:
   `agent-run` refuses a third review of the same subject unless you give it
   a reason (`--beyond-cap`). Past that, merge once no blocker or major is
   open, or record a blocker or change approach. A design or mockup is
   reviewed the same way: it is frozen after its re-check, and later details
   become acceptance checks in the build. Once nothing blocks, the change is
   the release: commit all of it, run
   `~/dotfiles/bin/effort-gate release "<why this commit is the release>"`,
   and start CI once (mark the draft ready). The tripwire holds any full CI run
   for a commit without that mark.

Infrastructure and configuration: live readback plus the affected behaviour.
Docs: compared with their source.

## 5. Deliver

Follow [delivery](references/delivery.md): branches, pull requests, history
rewrites, merge, deploy. Internal delivery proceeds; external actions need an approval recorded
in the effort file.

## 6. Verify

Dispatch a fresh agent to run `verify` against the "done when" list on the real
target (after deploy when the outcome lives on a deployed service), from the
other model family, or from the family named by `verifier:` (`delegate`
says when that applies): write its prompt to `.scratch/<effort>/runs/<run>/prompt.md`
(the effort file and how to reach the target; every verdict is the
verifier's) and run `~/dotfiles/bin/agent-run start codex verify <run-dir>`
from Claude, or `start claude verify` from Codex (the runtime `verifier:`
names, when set), then `agent-run wait <run-dir>`. Every approved brief includes this dispatch. Fix everything that
fails against the agreed list together, through step 4 as one new release, and
verify again; a finding outside it goes into the report as
a recommendation, not a new item or another round. Verification is complete
when every item passes.

## 7. Close

- Move lasting decisions into the project's docs (ADR, README, `AGENTS.md`).
- Delete plan, spec or ticket files the work made obsolete. Set the effort
  file to `status: done` and leave it: the weekly review counts and removes it.
- Remove the worktrees, branches, containers and background jobs this work
  created.
- Report from the effort file: the outcome, the evidence (naming any item
  checked only by a substitute), decisions worth knowing, and what Sebastian
  needs to do. Each reserved action still under "Not approved" ends the report
  as a yes/no question to him with your recommended answer, even when all local
  work is done.
- After substantial rework, an escaped defect or repeated steering: `retro`,
  then fix the environment (a check, a tool, or one rule) rather than adding
  prose.

## Staying on course

- The stop gate blocks the session named in `session:` from ending a turn
  while the effort file has open items; other sessions are never gated. To
  stop legitimately, set `status: blocked` with the blocker recorded, or
  `status: done` after `verify` passes (`done` with an unfinished item is
  still held). At close it holds the owner once more if items passed without
  a finished verify by the verifying family under `runs/`, or if "Not
  approved" lists actions the report does not ask. It also holds once for
  each milestone past its due time that is not `met`, `missed` or `dropped`.
- Waiting on a job or agent: record it under "Running tasks" with state
  `running`, and never end a turn without something that will wake you.
  Claude starts one background command per job or run (the job itself, or
  `agent-run wait <run-dir>`), never one combined wait, so each finish wakes
  it to act on that result. Codex runs one blocking wait in the foreground.
  Exit 124 from `agent-run wait` means the run went quiet: read its events,
  then wait again or stop it.
- Under T3, a restart kills background commands and running turns without
  waking anyone. While anything runs, keep one `schedule_task` interval of
  15 minutes bound to the thread. Its prompt has the session re-read the
  effort file, restart any wait that is gone, and judge progress against
  `## Milestones` from commits and merged work, not from whether processes
  are alive. It deletes the schedule once nothing runs. Record it as a
  `Wake heartbeat` row in state `armed`; the stop gate holds a T3 session
  with running tasks until that row exists. Update each row when its job
  ends. A watch that hits a time limit is restarted, never dropped.
- Keep the effort file current whenever a decision, approval, item status or
  next step changes. After compaction it is the source of truth. Write it in
  plain sentences a fresh reader follows; history belongs in git and
  `runs/`. The stop hook asks for a rewrite once it passes 20 KB.

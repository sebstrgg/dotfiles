---
name: engineering-workflow
description: Sebastian's path from request to verified result. Use at the start of any engineering task (feature, fix, new project, infrastructure change, review, diagnosis) and when scope, evidence or phase changes.
---

# Engineering workflow

The global instructions own authority and the meaning of done; this skill
owns the order and hands each stage to the skill that carries it:

1. Intake: the effort file; `unattended` when Sebastian is leaving.
2. Plan: the effort file, or `to-spec`, `to-tickets`, `implement-spec`.
3. Build: lanes per `delegate`.
4. Prove and review: `prove-it`, then `delegate`'s review loop.
5. Deliver: `ship`, which hands the open pull request to `babysit-pr`.
6. Verify: `verify` in a fresh child per `delegate`.
7. Close.

Each of those skills also loads on its own when its situation comes up
mid-task (an existing pull request, a request for proof). Questions,
reviews and diagnosis stop after intake with an answer unless a change is
requested; evidence about UI, runtime or device behaviour comes from
`prove-it`, for a diagnosis too. Match the ceremony to the task: a quick change (global
instructions) is made, checked once on the real target and reported.

## 1. Intake

- Gather context: repository instructions, docs and ADRs, the closest existing
  sibling when creating a new one, and any active `.scratch/*/effort.md` for
  this work. Taking an effort over: `~/dotfiles/bin/effort-gate claim <file>`,
  then continue from its Next.
- A delegated agent (its prompt is a brief from an orchestrator) works that
  brief and ends on its report. It creates no effort file and starts no
  reviewer, verifier or worker of its own.
- Otherwise: `~/dotfiles/bin/effort-gate new <effort>` creates
  `.scratch/<effort>/effort.md` from [the template](templates/effort.md).
  Fill in the brief before any product edit or background job:
  - **Outcome**, quoting his words, and **done when** items checkable on
    the real target. A named quality (fast, secure) is a measured item; a
    change to persisted state has an item that the new build starts on a
    copy of current data.
  - **Out**: what to stop and ask about. Everything else you decide.
  - **Approved**, **Not approved** and **Budget**.
- Unsettled intent: one round of numbered questions now, while Sebastian is
  here, each with your recommendation, and only the ones where his answer
  changes the outcome. Add to that round what you can foresee needing from
  him later, so he can leave: the direction of any UI without an approved
  one, however small, as a line per alternative (read the
  [design reference](references/design.md) first), a spend, a sign-in.
  State the rest as decisions. A new
  project or big feature with unsettled intent: `grilling`.
- Work that will run while Sebastian is away: `unattended` before he leaves.

Playbooks in `~/.agents/skills` (`grilling`, `to-spec`, `to-tickets`,
`implement-spec`, `codebase-design`, `domain-modeling`, `research`,
`prototype`, `tdd`, `diagnosing-bugs`, `retro`) don't load on their own: read
`~/.agents/skills/<name>/SKILL.md` and follow it. Steps in them that wait for
the user are covered by the approved brief: decide, record, continue.

## 2. Plan

- Small work: the effort file is the plan.
- Work spanning sessions or parallel lanes: `to-spec`, `to-tickets`, then
  `implement-spec` with lanes per `delegate`.
- On demand: `codebase-design`, `domain-modeling`, `research`, `prototype`.
- UI, visual design or copy: [design reference](references/design.md).
- New project or onboarding a repository: [baseline](references/new-project.md).

## 3. Build

- Test-first (`tdd`) at seams you choose. A failure that resists a first
  look: `diagnosing-bugs`.
- A fix records its root cause in the effort file before the edit, then fixes
  the class: find every sibling of the defect and fix or report the set.
  Never loosen a type, test or public contract to turn a check green: that
  shrinks the promise instead of keeping it.
- Run independent work in parallel from the start: lanes per `delegate`, and
  paid or rate-limited calls at the provider's actual limits within the
  budget. Never leave work idle behind something it does not depend on.
  Splitting work is your decision, not a question. The two-heavy-jobs limit
  covers builds and browser suites on the Mac, not children running
  elsewhere.
- Hit every surface the change touches: each entry point, client and adapter,
  the reverse state (undo, re-enable), docs.
- Commit in small, meaningful steps.

## 4. Prove and review

1. `prove-it`: the change has its intended effect on the real target, or on a
   local build against a copy of the real state when it ships through CI.
2. The CI job's fast steps (lint, format, types, repository-root checks)
   across the whole repository, and every test that exercises changed code,
   locally: CI runs them on the whole repository too.
3. Code where a missed bug is expensive: the review loop in `delegate`.
4. Once nothing blocks, that commit is the release: commit everything, run
   `~/dotfiles/bin/effort-gate release "<why>"`, and start full CI once (mark
   the draft ready). The tripwire holds a full run on any other commit.

## 5. Deliver

`ship`: the pull request, its title and body, the merge gate, merge and
deploy, or a hand-over at ready-to-merge. `babysit-pr` watches it.
[Delivery](references/delivery.md): a secret in history, shared areas, CI
data and spend, clean-up.

## 6. Verify

A fresh verifier from the other model family runs `verify` against the "done
when" list on the real target, after deploy when the outcome lives on a
deployed service: `delegate_task` with the verify brief in `delegate`. Fix
every failure on the agreed list as one new release and verify again. A
finding outside the list goes into the report as a recommendation.

## 7. Close

- Lasting decisions go into the project's docs (ADR, README, `AGENTS.md`).
  Delete plan, spec and ticket files the work made obsolete.
- Set the effort file to `status: done`; the weekly review removes it.
- Remove the worktrees, branches, containers and jobs this work created.
- Report per the global instructions: what is blocked on Sebastian first,
  then the calls he may overrule (each decision you made for him, with its
  reason), the outcome and evidence (name any substitute check). Open reserved actions go through the question tool.
- After substantial rework, an escaped defect or repeated steering: `retro`,
  and fix the environment (a check, a tool, one rule) rather than add prose.

## Staying on course

- The stop gate holds the session named in `session:` while "done when" has
  open items. To stop legitimately: `status: blocked` with the blocker
  recorded, or `status: done` after `verify` passes.
- Waiting: T3 child tasks and `watch_pull_request` wake you; end the turn
  instead of polling. Any other job: Claude runs one background command whose
  exit wakes it (the job itself, or a `gh run watch`); Codex runs one blocking
  wait in the foreground. Never a sleep loop. Record each under "Running
  tasks" and update its row when it ends.
- Keep the effort file current whenever a decision, approval, item or next
  step changes. After compaction it is the source of truth.

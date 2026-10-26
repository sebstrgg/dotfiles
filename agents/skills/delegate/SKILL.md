---
name: delegate
description: Hand work to other agents - choosing runtime, model and effort, writing the brief, running parallel lanes, cross-family review and verification. Use when a task has parallel parts, needs a model or family other than yours, needs an independent reviewer or verifier, or when Sebastian says "delegate", "use Codex/Sol/Opus for this" or "run it in parallel".
---

# Delegate

The orchestrator owns the outcome and the critical path, picks the model per
piece of work and checks every result itself. Do the work yourself when the
work is the judgment, or when the brief would cost more than doing it.

## Models

- **Claude Opus 5.5**: the strongest judgment and eye for design. Intent,
  product and UI decisions, design and copy, cross-module integration, hard
  diagnosis, review verdicts.
- **Codex `gpt-6.1-sol`**: the workhorse with the most capacity. Tickets,
  refactors, migrations, tests and CI fixes, infrastructure, data and logs,
  parallel lanes, thorough reviews. `high` by default, `xhigh` for complex or
  high-stakes work and reviews.
- **Claude Sonnet 5.5**: Claude-side reading and extraction, checklist
  browser walks (Opus judges), well-specified edits, docs from settled
  decisions.
- **Codex `gpt-6-astra`**: second opinions on key designs.
- Haiku and `gpt-6-luna`: tiny bounded tasks only. Never `max` effort: it
  costs many times more for almost nothing; `high` or `xhigh`.
- When Sebastian names a model or runtime, use it. Claude tokens are the
  scarcest: give Sol everything a precise brief can carry.

## How to start a child

- In T3 Code, every child that needs another family, a model option or its
  own checkout goes through `delegate_task`: `target` from
  `orchestrator_capabilities`, effort in `target.options`, `role`, a stable
  `clientRequestId`, `mode: async`. It appears in Sebastian's app as a
  thread, and its completion wakes you: end the turn instead of polling.
  `isolation: worktree` starts from your local commit; uncommitted edits are
  not copied, and it needs a project rooted in a git repository.
- The native Agent tool only for Claude work on a model it supports, when
  you request no model options and `orchestrator_capabilities` shows none
  inherited: quick reading, search and extraction. Anything else in T3 goes
  through `delegate_task`, so it shows up as a thread.
- A follow-up round is a new `delegate_task` carrying the brief, earlier
  findings and your answers, never `t3_thread_send` to the child.
- Outside T3, Claude uses the `codex` plugin for Codex reviews and rescue;
  say when a cross-family step could not run.
- Record each child's task handle under "Running tasks" in the effort file.

## Briefs

- The outcome, the real target and how done is proven, the boundaries
  (files, authority, what to leave alone) and what to report. Pointers
  (effort file, spec, commits), not copies. A child knows only its brief
  and the global instructions.
- A child works its brief and reports back. It starts no reviewers, verifiers
  or further children and makes no paid calls; the orchestrator decides
  those.
- Lanes do not overlap: one writer per file or resource, build caches and
  worktrees included.
- Children commit locally. The orchestrator pushes, opens the pull request
  and starts CI.
- A child's "done" is a claim: check it another way before relying on it. A
  lane with no new evidence after two rounds is stopped and re-briefed or
  re-routed.
- UI lanes get the approved design and a way to see their result; Claude
  reviews the rendering before it counts.

## Verification and review

- `verify` runs in a fresh child from the other model family: Claude-built
  work goes to Codex, Codex-built work to Claude. A same-family verify counts
  only when Sebastian ruled the other family out, or the target is out of its
  reach (a tool, sign-in or device only your family has): record
  `verifier: <runtime>` in the effort file's front matter with the evidence
  under Decisions. When the other family just cannot run now (signed out,
  usage limit), the items stay open or go `blocked`. A fork of your own
  context is not fresh.
- Cross-family code review: `review-loop`.

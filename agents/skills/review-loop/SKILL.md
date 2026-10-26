---
name: review-loop
description: Budgeted cross-family code review before a pull request goes ready - the other model family reviews, you fix what is right and push back on the rest. Use for changes where a missed bug is expensive (security, auth, secrets, persisted data, migrations, deletion, money, concurrency, public contracts, large cross-module changes), or when Sebastian says "review loop", "sol loop" or "get a second opinion".
---

# Review loop

You own the code; a reviewer from the other model family checks it. Fix what
is right, push back on what is wrong, and stop when you agree or the budget
ends. The goal is the smallest change that meets the intent: review makes it
correct, not bigger.

## Budget

- Three rounds. Round one reviews the whole change; later rounds only the
  fixes, what they touch and the findings still open.
- Stop early when a round returns only minors. Decline nits, style and
  docs-only comments that don't change behaviour.
- One reviewer at a time. The reviewer starts no subagents or reviewers.

## Each round

1. `delegate_task` to the other family (Claude-written code goes to Codex
   `gpt-6.1-sol` at `xhigh`; Codex-written code to Claude Opus), role
   `review`, a new `clientRequestId` per round. The brief: the goal, the diff
   range or commits, the worktree, "read-only: report findings, change
   nothing", and for later rounds the earlier findings with your answers.
2. Findings come back as `blocker`, `major` or `minor`, each with file and
   line, failure scenario and smallest fix. Confirm each in the code before
   acting on it.
3. Fix confirmed blockers and majors in this change. Minors become issues or
   are declined with a reason. Scope creep is declined even when it is right:
   file it.

## Record

Keep the findings and your answers in the effort file. The pull request body
ends with one line: `Reviewed with review-loop: <n> rounds, <model>; verdict
<approved | open: ...>`. Never soften an unresolved objection: if the
reviewer still disagrees, say so there.

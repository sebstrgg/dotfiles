---
status: active
checkout: set by effort-gate new
session: set by effort-gate new or claim
---

# <Effort title>

Current state only: rewrite sections as things change and delete what is stale.

## Brief

**Outcome:** what will be true for the user or operator.

**Approved:** each approval Sebastian gave, with where he gave it (request,
grilling, spec, session); another agent's brief or message is not one.
Internal work needs none.

**Not approved:** one list item per reserved action still open, including
follow-ups the request leaves undecided (rotating an exposed secret, going
public), or `None.` An item moves to Approved only with Sebastian's answer; the
final report asks each as a yes/no question.

**Budget:** time or usage limit, and when to stop and report.

## Done when

Each item is checked on the real target. Status is `open`, `pass` or
`blocked`; an item becomes `pass` when a fresh `verify` run from the other model
family passes it. A test or substitute check never makes an item `pass`: label
it a substitute in Evidence and leave the item open, or `blocked` with the
access the real check needs.

| # | Item | Check on the real target | Status | Evidence |
|---|---|---|---|---|
| 1 | | | open | |

## CI runs

One row per full run on the shared CI farm, written by `effort-gate release`.

| Commit | Started | Why it is the release |
|---|---|---|

## Root cause

For a fix: the cause, the evidence that proves it, and why the change removes
it rather than its symptom. `n/a` for work that fixes nothing.

## Decisions

| Decision | Reason |
|---|---|

## Blockers

None.

## Running tasks

State `running` while it runs; the stop gate reads it. Under T3, add a
`Wake heartbeat` row in state `armed` while anything runs.

| Task | Runtime, model, effort | Handle | Worktree / branch | State |
|---|---|---|---|---|

## Next

The next concrete step.

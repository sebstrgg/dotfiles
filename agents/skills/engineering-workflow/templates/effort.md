---
status: active
checkout: set by effort-gate new
session: set by effort-gate new or claim
---

# <Effort title>

Current state only: rewrite sections as things change and delete what is stale.

## Brief

**Outcome:** what will be true for the user or operator.

**Approved:** each approval with where it was given (request, grilling, spec,
session). Internal work needs none.

**Not approved:** reserved actions that are still open.

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

## Decisions

| Decision | Reason |
|---|---|

## Blockers

None.

## Running tasks

State `running` while it runs; the stop gate reads it.

| Task | Runtime, model, effort | Handle | Worktree / branch | State |
|---|---|---|---|---|

## Next

The next concrete step.

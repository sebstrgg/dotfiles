---
name: delegate
description: Hand work to other agents through T3 - which model and effort does which work, briefs, parallel lanes, the review loop, verification. Use when work has parallel parts, needs another model, an independent reviewer or a verifier, before a risky change (security, auth, secrets, data, migrations, money, concurrency, public contracts) goes ready, or when Sebastian says "delegate", "use Codex/Sol/Opus", "prioritize Codex/Claude", "in parallel", "review loop", "sol loop" or "second opinion".
---

# Delegate

The orchestrator owns the outcome and the critical path, picks the model for
each piece of work and checks every result itself. Do the work yourself when
the work is the judgment, or when the brief would cost more than doing it.

## Who does what

Sebastian's ruling comes first: "prioritize Codex" (he has weekly Codex usage
to spend), "prioritize Claude", a model he names, a runtime he rules out.
Record it under Decisions in the effort file, so a continuation keeps it, and
apply it to every dispatch until he changes it.

Without a ruling, Claude usage is the scarcer: Sol takes everything a precise
brief can carry, Claude keeps the judgment.

| Work | Model | Effort |
|---|---|---|
| Implementation: tickets, refactors, migrations, tests, CI fixes, infrastructure, data and logs, parallel lanes | Codex `gpt-6.1-sol` | `high`; `xhigh` when complex or high-stakes |
| Code review | `gpt-6.1-sol` | the review table below |
| Verifying Claude-built work | `gpt-6.1-sol` | `high` |
| Design, UI, copy and product decisions | Claude `claude-opus-5-5` | `high` |
| Review of a design, rendered UI or copy | `gpt-6.1-sol` for the other family's eye on the brief, layout, states and accessibility; `claude-opus-5-5` when it turns on taste, voice or brand | the review table below |
| A diagnosis Sol could not crack; cross-module integration | `claude-opus-5-5` | `high` |
| Verifying Codex-built work | `claude-opus-5-5` | `medium` |
| Claude-side work without Opus's judgment: reading and extraction across code, logs and transcripts, checklist browser walks (Opus judges), docs and PR bodies from settled decisions | `claude-sonnet-5-5` | `medium` |
| A tiny bounded lookup | Haiku (native Agent) or `gpt-6-luna` | `low` |

- **"Prioritize Codex":** Sol also takes the Sonnet row and the first pass of
  a hard diagnosis. Claude keeps design, UI and copy work and verifying
  Codex-built work.
- **"Prioritize Claude":** Opus or Sonnet also take implementation lanes. Sol
  keeps code review and verifying Claude-built work.
- When the stakes justify it, Opus and Sol work the same hard problem
  independently and you compare.
- Never `gpt-6-astra` (Sebastian's ruling) and never `max` effort.

## Starting a child

Every child goes through `delegate_task`. The exception is the native Agent
tool, for quick reading or search on Sonnet or Haiku with no model options.
Always set the effort: Sol defaults to `low`.

```json
{
  "title": "Review: <effort> round 1",
  "role": "review",
  "target": {"providerInstanceId": "codex", "model": "gpt-6.1-sol",
             "options": {"reasoningEffort": "high"}},
  "mode": "async",
  "clientRequestId": "<effort>-review-r1",
  "task": "<the brief>"
}
```

- Claude target:
  `{"providerInstanceId": "claudeAgent", "model": "claude-opus-5-5", "options": {"effort": "high"}}`.
- Check the model and options the result reports, and report what each child
  actually ran on. Record the task under "Running tasks" with `T3`, the model
  and the effort in its runtime and its `clientRequestId` as the handle, then
  end the turn: its completion wakes you.
- Outside T3, Claude reaches Codex through the `codex` plugin. Say so when a
  cross-family step could not run.

## Briefs

- Give the outcome in Sebastian's words, the real target and how done is
  proven, the boundaries (files, authority, what to leave alone) and what to
  report. Use pointers (effort file, spec, commits), not copies. A child
  knows only its brief and the global instructions: put every rule and fact
  it needs in the brief.
- A child starts no reviewers, verifiers or further children, makes no paid
  calls and asks nothing: it takes its recommendation on what can be undone
  and lists it in its report; a finding that changes the outcome or a
  reserved action ends its run with the question in its report.
- One writer per file or resource. Give each lane its own worktree and build
  cache (a `CARGO_TARGET_DIR`), and clean only what is yours. Children commit
  locally; the orchestrator pushes and opens the pull request.
- A child's "done" is a claim: check it another way. Stop a lane after two
  rounds with no new evidence, then re-brief or re-route it.
- UI lanes get the approved design and a way to see their result.

Bad: "Fix the ranking bug we discussed." The child never saw that
discussion.

Good: "Jobs with salary ranges rank below jobs without one
(.scratch/ranking/effort.md, item 2). Fix it in src/rank.ts. Done when
`npm test -- rank` passes and the 500-job sample's precision is at least
0.92. Leave the UI alone. Report the commit and the precision."

## Review loop

A fresh reviewer checks code where a missed bug is expensive before its pull
request goes ready. You own the code: fix what is right, push back on what is
wrong. Review makes the change correct, not bigger.

- **Reviewer:** one at a time, always a fresh child, from the table above.
  A design or mockup gets one review and one re-check, then it is frozen.
- **Effort:** match the stakes, not the habit. The highest row that applies
  wins, however small the diff.
  - `xhigh`: security, auth, secrets, money, data loss, migrations,
    concurrency, or a large cross-module change.
  - `high`: ordinary logic changes.
  - `medium`: a small change in one module that is easy to roll back.
- **Budget:** three rounds. Later rounds cover only the fixes and the
  findings still open. Stop early when a round returns only minors.
- **Brief:**
  ```text
  Review <goal> in <checkout>, commits <base>..<head>. Read-only: change
  nothing, start no agents. Each finding: blocker | major | minor, file:line,
  failure scenario (input or state -> wrong result), smallest fix. Skip
  style and docs-only nits.
  <round 2+: earlier findings, and the commit that fixed each or why you declined it>
  ```
- **Findings:** confirm each in the code first. Fix blockers and majors in
  this change. File or decline minors and scope creep, with a reason.
- **Record:** findings and answers go in the effort file. The pull request
  gets one line: `Reviewed by <model>, <n> rounds: approved`, or
  `open: <objection>`. Never soften an objection the reviewer still holds.

## Verification

`verify` runs in a fresh child from the other model family, per the table.

- Same family counts only when Sebastian ruled the other family out, or the
  target is out of its reach. Record `verifier: <runtime>` in the effort's
  front matter, with the evidence under Decisions. "Prioritize Codex" is not
  such a ruling: verifying Codex-built work stays with Claude.
- When the other family just can't run now, the items stay open or go
  `blocked`. A fork of your own context is not fresh.
- Brief, with role `review`:

```text
Read ~/dotfiles/agents/skills/verify/SKILL.md and follow it. Effort file:
<path>. Real target: <URL, host or device, and how to reach it>. Write your
report to .scratch/<effort>/verification.md and change nothing else.
```

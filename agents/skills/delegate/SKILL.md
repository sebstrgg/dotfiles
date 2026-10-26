---
name: delegate
description: Hand work to other agents through T3 - model choice, briefs, parallel lanes, the review loop, verification. Use when work has parallel parts, needs another model, an independent reviewer or a verifier, before a risky change (security, auth, secrets, data, migrations, money, concurrency, public contracts) goes ready, or when Sebastian says "delegate", "use Codex/Sol/Opus", "in parallel", "review loop", "sol loop" or "second opinion".
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
  high-stakes work. Review effort: the review loop below.
- **Claude Sonnet 5.5**: Claude-side work that needs Claude's tools but not
  Opus's judgment: reading and extraction across code, logs and transcripts,
  checklist browser walks (Opus judges), well-specified edits, docs and PR
  bodies from settled decisions.
- **Codex `gpt-6-astra`**: second opinions on key designs. `high`, or `xhigh`
  when genuinely hard.
- The hardest problems go to Opus or Astra, whichever fits. When the stakes
  justify it, both work independently and the orchestrator compares.
- Haiku and `gpt-6-luna`: tiny bounded tasks only. Never `max` effort: it
  costs many times more for almost nothing.
- When Sebastian names a model or runtime, use it.

Claude tokens are the scarcest. A Claude orchestrator gives Sol everything a
precise brief can carry and keeps the judgment. A Codex orchestrator runs its
own Sol workers and brings in Opus for design, rendered-UI and copy review and
a diagnosis Sol couldn't crack.

## Starting a child

In T3 every child goes through `delegate_task`. The exception is the native
Agent tool, for quick reading or search on Sonnet or Haiku with no model
options. Always set the effort: Sol defaults to `low`.

```json
{
  "title": "Review: <effort> round 1",
  "role": "review",
  "target": {"providerInstanceId": "codex", "model": "gpt-6.1-sol",
             "options": {"reasoningEffort": "xhigh"}},
  "mode": "async",
  "clientRequestId": "<effort>-review-r1",
  "task": "<the brief>"
}
```

- Claude target:
  `{"providerInstanceId": "claudeAgent", "model": "claude-opus-5-5", "options": {"effort": "high"}}`.
- Record the task under "Running tasks" with `T3` in its runtime, then end the
  turn: its completion wakes you.
- Outside T3, Claude reaches Codex through the `codex` plugin. Say so when a
  cross-family step could not run.

## Briefs

- Give the outcome, the real target and how done is proven, the boundaries
  (files, authority, what to leave alone) and what to report. Use pointers
  (effort file, spec, commits), not copies. A child knows only its brief and
  the global instructions: put every rule and fact it needs in the brief.
- A child starts no reviewers, verifiers or further children and makes no
  paid calls.
- One writer per file or resource. Give each lane its own build cache (a
  `CARGO_TARGET_DIR`) and worktree, and clean only what is yours. Children
  commit locally; the orchestrator pushes and opens the pull request.
- State the model and effort of every dispatch in the effort file, and
  report what each child actually ran on (`task_status`, or the child
  thread's model).
- A child's "done" is a claim: check it another way. Stop a lane after two
  rounds with no new evidence, then re-brief or re-route it.
- UI lanes get the approved design and a way to see their result; Claude
  reviews the rendering.

Bad: "Fix the ranking bug we discussed." The child never saw that
discussion.

Good: "Jobs with salary ranges rank below jobs without one
(.scratch/ranking/effort.md, item 2). Fix it in src/rank.ts. Done when
`npm test -- rank` passes and the 500-job sample's precision is at least
0.92. Leave the UI alone. Report the commit and the precision."

## Verification

`verify` runs in a fresh child from the other model family: Claude-built work
goes to Codex, Codex-built work to Claude.

- Same family counts only when Sebastian ruled the other family out, or the
  target is out of its reach. Record `verifier: <runtime>` in the effort's
  front matter, with the evidence under Decisions.
- When the other family just can't run now, the items stay open or go
  `blocked`. A fork of your own context is not fresh.
- Brief, with role `review`:

```text
Read ~/dotfiles/agents/skills/verify/SKILL.md and follow it. Effort file:
<path>. Real target: <URL, host or device, and how to reach it>. Write your
report to .scratch/<effort>/verification.md and change nothing else.
```

## Review loop

A fresh reviewer checks code where a missed bug is expensive before its pull
request goes ready. You own the code: fix what is right, push back on what is
wrong. Review makes the change correct, not bigger.

- **Reviewer:** `gpt-6.1-sol` in a fresh child, whoever wrote the code.
  Design, rendered UI and copy go to `claude-opus-5-5` instead. One reviewer
  at a time.
- **Effort:** match the stakes, not the habit.
  - `medium`: a small change in one module that is easy to roll back.
  - `high`: ordinary logic changes.
  - `xhigh`: security, auth, secrets, money, data loss, migrations,
    concurrency, or a large cross-module change.
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

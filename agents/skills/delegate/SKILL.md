---
name: delegate
description: Delegating work to subagents or other runtimes. Use when choosing a model or effort, dispatching Claude or Codex workers, running parallel lanes, verification or cross-family review.
---

# Delegate

The main session orchestrates: it owns the outcome and the critical path, picks
runtime, model and effort per piece of work, and validates results itself. Do
the work yourself when the work is the judgment, or when writing the brief
costs more than doing it.

## Models

- **Claude Opus 5.5**: strongest reasoner and best eye for design. Intent,
  product and UI judgment, design direction and copy, cross-module
  integration, hard diagnosis, review verdicts.
- **Codex `gpt-6.1-sol`**: the workhorse with the most capacity. Tickets,
  refactors, migrations, test and CI fixes, infrastructure changes, data and
  log work, parallel lanes. `high` by default; `xhigh` for complex,
  cross-cutting or high-stakes work and pre-merge reviews.
- **Claude Sonnet 5.5**: Claude-side work that needs Claude's tools but not
  Opus's judgment: reading and extracting across code, logs and transcripts;
  browser walkthroughs against a checklist (Opus judges); well-specified edits;
  docs and PR bodies from settled decisions; watching CI and long jobs.
- **Codex `gpt-6-astra`**: second opinions on key designs. `high`, or `xhigh`
  when genuinely hard.
- The hardest problems go to Opus or Astra, whichever fits; when stakes justify
  it, both work independently and the orchestrator compares.
- Haiku 5.5 and `gpt-6-luna`: tiny bounded tasks only. Older Sol versions stay
  unused.
- When Sebastian names a runtime or model, use it.

Claude tokens are the scarcest. A Claude orchestrator gives Sol everything a
precise brief can carry and keeps the judgment. A Codex orchestrator runs its own
Sol agents and brings in Opus for design, rendered-UI and copy review, a
diagnosis Sol couldn't crack, and cross-family review.

## Briefs

- State the outcome, the real target and how done is proven, the boundaries
  (files, authority, what to leave alone), and what to report. Give pointers
  (effort file, spec, tickets, commits), not copies.
- A fresh subagent knows only its brief and the global instructions: put every
  rule and fact it needs in the brief.
- UI lanes get the approved design and a way to see their result rendered;
  Claude reviews that rendering before it counts.
- A delegated agent works its brief and reports back. It does not start second
  opinions, reviews or further delegation; the orchestrator decides those.
- Workers make no paid or metered calls (`claude -p`, model APIs). Only the
  orchestrator spends, within what Sebastian approved; the cross-family verify
  and reviews the workflow calls for are part of every approved brief.
- Lanes do not overlap: one writer per file or resource.
- Workers commit locally. The orchestrator pushes, opens the pull request and
  starts CI, batching reviewed work into one PR.
- A worker's "done" is a claim: check it through a different path before
  relying on it. A lane with no new evidence after two rounds is stopped and
  re-briefed or re-routed.
- State model and effort for every dispatch; report what each run actually
  used, from its session record. Record handles in the effort file.

## Verification and review

- `verify` runs in a fresh agent, from the other model family where the target
  is reachable from it: a Claude orchestrator sends it to Codex, a Codex
  orchestrator to Claude, both through `agent-run`. A subagent that forks the
  orchestrator's context is not fresh.
- Cross-family code review for expensive-to-miss code: Codex reviews
  Claude-written code, Claude reviews Codex-written code. Fix confirmed findings
  and re-check once.
- Reviews are read-only and report findings only: severity, file and line,
  failure scenario, smallest fix, verdict. Confirm each finding in the code.

## Claude Code mechanics

- Pass `model` and `effort` on every Agent call; without them subagents run on
  the session's model. Building that needs no Claude tools goes to Codex.
- Use a subagent for self-contained work that returns a summary (sweeps, logs,
  test output, research); keep iterative or quick work in the main session.
- When a side task needs most of the conversation and `fork` is offered, fork
  instead of re-briefing.
- Continue a finished subagent with `SendMessage` to its ID. Explore and Plan
  are one-shot. Subagents stop with the session.
- `isolation: "worktree"` branches from the default branch, not the session's
  HEAD; a subagent that needs unmerged commits works in the task's worktree.
- Wait on completion notifications or one Monitor with an until-condition,
  never a sleep loop.
- When you keep briefing the same kind of worker, propose a definition in
  `~/.claude/agents/` with model, effort and tools pinned.

## Cross-runtime runs

- `~/dotfiles/bin/agent-run start <codex|claude> <role> <run-dir>` starts every
  `codex exec` and `claude -p` run, from the task's own worktree, with the
  prompt in `<run-dir>/prompt.md`. The role (`work`, `continue`, `verify`,
  `review`) pins model, effort and access, detaches the run and records it in
  the run folder; `--model` and `--effort` override. `agent-run wait <run-dir>`
  blocks until it ends and prints the last message and resume handle: from
  Claude as a background command, from Codex in the foreground.
- `agent-run` starts Codex lanes, verifiers and reviewers signed out of Claude;
  only a `continue` run keeps Claude reachable.
- Run folders live under `.scratch/<effort>/runs/`, never `/tmp`: a restart
  wipes `/tmp` and the work with it.
- A run stopped by a usage limit: schedule a wake-up for the reset time and
  resume it (`codex exec resume <thread>`, `claude -p --resume <session>`).
- From Claude, the `codex` plugin (`/codex:review`,
  `/codex:adversarial-review`, `codex:codex-rescue`) also works. An unfinished
  job is a clean-up obligation.
- Use one shared brief file plus a short per-task prompt.

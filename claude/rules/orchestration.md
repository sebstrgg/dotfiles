# Claude Code orchestration

Claude Code specifics for the shared multi-agent rules in the global instructions.

## Subagents

- Pass `model` and `effort` on every Agent call, chosen per the global Delegation section;
  without them Explore and other subagents run on the session's model. Building work that
  needs no Claude tools goes to Codex instead.
- A fresh subagent knows only its brief and CLAUDE.md: no auto memory, invoked skills or
  files you have read, and Explore and Plan skip CLAUDE.md too. Put every rule and fact it
  needs in the brief. Use one for self-contained work that returns a summary: sweeps, logs,
  test output, parallel research. Keep iterative, multi-phase or quick work in the main
  conversation.
- When the session offers `fork` and a side task needs most of this conversation, fork
  instead of re-briefing: a fork inherits the history and reuses the prompt cache, on the
  session's model.
- Continue a finished subagent with `SendMessage` to its ID instead of spawning a new one;
  it keeps its history and cache. Explore and Plan are one-shot. Subagents stop with the
  session; record their IDs in the ledger and re-arm watchers after restarts.
- `isolation: "worktree"` branches from the default branch, not the session's HEAD. A
  subagent that needs unmerged commits works in the task's own worktree instead.
- When you keep briefing the same kind of worker, propose a definition in
  `~/.claude/agents/` with its model, effort and tools pinned.
- Wait with `run_in_background` and its completion notification, or Monitor with an
  until-condition, inside the cache lifetime from the global instructions.

## Codex

- The installed `codex` plugin exposes Codex as the `codex:codex-rescue` subagent and as
  `/codex:rescue`, `/codex:review`, `/codex:adversarial-review` and `/codex:transfer`. Use
  it when a second model architecture earns its cost: a due cross-family review of
  Claude-written code, a diagnosis Claude is stuck on, or background work running
  alongside mine. Track background jobs through `/codex:status`, `/codex:result` and
  `/codex:cancel`; an unfinished job is a cleanup obligation.
- Implementation: `codex exec` in the task's own git worktree, model and effort pinned,
  prompt on stdin, JSON events, last message and an exit marker written to a run folder,
  started detached in its own process session (`setsid`, e.g. via Python on macOS) so it
  survives the Claude session. Resume a run with `codex exec resume <thread>`. Wait for
  the exit marker with one Monitor, never a sleep loop.
- A Codex worker launched by a Claude orchestrator is a worker, not an orchestrator: its
  brief forbids invoking `claude` or any other agent for reviews or delegation, and the
  launch blocks the `claude` CLI (a `ZDOTDIR` whose profiles put an exit-126 `claude`
  first on `PATH`). The orchestrator owns every review.
- Reviews and probes: read-only sandbox. Full access only when the task needs Docker or
  network, never for reviews.
- A shared brief file plus a short per-task prompt; give context pointers, not copies.

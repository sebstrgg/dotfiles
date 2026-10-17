# Claude Code orchestration

Claude Code specifics for the shared multi-agent rules in the global instructions.

## Subagents

- Pass `model` on every Agent call, chosen from the global menu: `haiku`, `sonnet` or
  `opus`. Grunt work that needs no Claude judgment goes to Codex instead.
- Claude subagents stop with the session; resume them by ID from the ledger. Re-arm
  watchers after restarts.
- Wait with `run_in_background` and its completion notification, or Monitor with an
  until-condition, inside the cache lifetime from the global instructions.

## Codex

- The installed `codex` plugin exposes Codex as the `codex:codex-rescue` subagent and as
  `/codex:rescue`, `/codex:review`, `/codex:adversarial-review` and `/codex:transfer`. Use
  it when a second model architecture earns its cost: independent review of Claude-written
  code, a diagnosis Claude is stuck on, or background work running alongside mine. Track
  background jobs through `/codex:status`, `/codex:result` and `/codex:cancel`; an
  unfinished job is a cleanup obligation.
- Implementation: `codex exec` in the task's own git worktree, model and effort pinned,
  prompt on stdin, JSON events, last message and an exit marker written to a run folder,
  started detached in its own process session (`setsid`, e.g. via Python on macOS) so it
  survives the Claude session. Resume a run with `codex exec resume <thread>`. Wait for
  the exit marker with one Monitor, never a sleep loop.
- Reviews and probes: read-only sandbox. Full access only when the task needs Docker or
  network, never for reviews.
- A shared brief file plus a short per-task prompt; give context pointers, not copies.

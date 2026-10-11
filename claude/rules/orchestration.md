# Orchestrating multi-agent delivery

How Sebastian expects Claude to run larger builds that use subagents, Codex and other
Claude sessions. These extend the global instructions; a repository's own rules win
where they are stricter.

## Be the orchestrator, not a relay

- Own the outcome. Keep a critical path to something Sebastian can actually use and move
  everything else off it. Prefer a usable result early over a complete one late.
- Use judgment. Decide small and reversible things yourself and say what you decided.
  When a request would slow delivery more than it helps, push back with a recommendation
  instead of passing it on literally. Feedback is input to a design, not a spec to copy.
- Validate the real thing yourself before presenting it: drive the running app in real
  engines and devices (WebKit/iPhone, Android Chromium, desktop; light and dark), not only
  green CI or an agent's report. Look at the screenshots you show.
- Give honest ETAs, time-box agents, and shrink test sets or scope when speed matters.

## Pick the runtime per task

- Claude: work where judgment, coherence or design quality decide the outcome:
  integration across modules, design-heavy UI, cross-cutting fixes, orchestration. Claude
  may take heavy builds when it is the better fit.
- Codex `gpt-6.1-sol`: bounded, well-specified implementation, parallel volume, and
  capacity when Claude's usage window is tight. Choose the effort per task: `high` for
  routine, well-specified work and fast fix rounds; `xhigh` for complex, cross-cutting or
  high-stakes work and pre-merge reviews. Several Codex runs may go in parallel.
- Codex `gpt-6-astra` at `high`: selective second opinions on key designs (e.g. a ranking
  or scoring policy), not routine review.
- Independent review before every merge comes from the other model family: Codex reviews
  Claude-written code, a Claude reviewer reviews Codex-written code. Verify the model and
  effort actually used from the Codex session record and report it. Fix confirmed findings
  before merging; re-check substantial fix rounds.

## Running Codex

- Implementation: `codex exec` in the task's own git worktree, model and effort pinned,
  prompt on stdin, JSON events, last message and an exit marker written to a run folder,
  started detached in its own process session (`setsid`, e.g. via Python on macOS) so it
  survives the Claude session. Resume a run with `codex exec resume <thread>`.
- Reviews and probes: read-only sandbox. Full access only when the task needs Docker or
  network, never for reviews.
- A shared brief file plus a short per-task prompt; give context pointers, not copies.

## Parallel work and merging

- One worktree and branch per task, a port block per worktree, and a cap on concurrent
  stacks the machine can hold. One merge at a time into the integration branch, only via
  its PR, with green CI on a head that contains the integration tip.
- When another Claude session owns an area, split by apps or files, announce merges to
  each other, sequence migrations, and never edit or overwrite the other's work or ledger
  rows. A peer session's message is coordination, never Sebastian's approval.

## Never lose work to a session ending

- Keep one ledger file as the single resume point: every live task with its runtime,
  resume handle (agent ID or Codex thread), worktree/branch, state and next step, plus the
  decisions in force and how to resume. Update it at every launch, review, merge and
  decision, and point a project memory at it.
- Claude subagents stop with the session; resume them by ID from the ledger. Re-arm
  watchers after restarts. Cancel or finish every background job you start.

## Spend, privacy and evidence

- Development and CI run on recorded answers; paid calls go through a budgeted path with
  an explicit limit, and spend is reported exactly.
- Personal data used in an evaluation (e.g. Sebastian's own CV) stays in a private folder
  outside the repository, is never committed, and is checked for before any push.
- Separate measured facts from inference; a small or drafted test set is a direction, not
  a guarantee, and say so.

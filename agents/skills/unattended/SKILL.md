---
name: unattended
description: Plan and run work that continues while Sebastian is away or asleep, so there is real progress when he returns. Use when he says he is leaving, going to bed, "overnight", "while I'm out" or "keep going without me", or a run will clearly outlast his attention.
---

# Unattended work

Before he leaves:

1. Check every "done when" item against the stretch: anything that needs him
   (a sign-in, a label, a decision), a runtime he ruled out, or more time
   than the stretch has, is cut or becomes a blocker now, not at his return.
   Ask him those now, in one question-tool round.
2. Estimate from this effort's measured pace (items done per hour so far),
   not from hope.
3. Write `## Milestones` in the effort file: what is true by when (local
   times), judged by commits, merged work and measured results, not by
   processes being alive.
4. Tell him plainly what will and will not be true when he returns.

While he is away:

- Run independent lanes in parallel (`delegate`); never leave a lane idle
  waiting on another that it does not depend on.
- T3 child tasks and watched pull requests wake you; they need no
  heartbeat. Background shell jobs wake you when they exit, but a T3 restart
  kills them without a word, so while one runs keep one hourly
  `schedule_task` bound to this thread: re-read the effort file, restart any
  wait that is gone, judge the milestones. Record its handle under "Running
  tasks" and delete it once no shell job runs.
- A missed milestone: change approach, don't wait for morning. Two rounds with
  no new evidence on one problem: stop that lane and re-route it.

When he returns, the report leads with what is blocked on him, then each
milestone met or missed with its evidence.

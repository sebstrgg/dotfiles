---
name: unattended
description: Plan and run work that continues while Sebastian is away or asleep, so there is real progress when he returns. Use when he says he is leaving or heading to bed, "overnight", "while I'm out", "I'm off" or "keep going without me", or a run will clearly outlast his attention - even when the task itself is ordinary engineering.
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
   processes being alive. Due is a date and time: the daily digest reads it.
   ```markdown
   | Due (Stockholm) | Milestone | Evidence | State |
   |---|---|---|---|
   | 2026-10-27 02:00 | Ranking change merged and deployed | | open |
   | 2026-10-27 06:00 | Precision measured on the 500-job sample, >= 0.92 | | open |
   ```
   State is `open`, `met`, `missed` or `dropped`.
4. Tell him plainly what will and will not be true when he returns, as a
   range from the pace so far.

   Bad: "I'll keep working on it overnight and report in the morning."

   Good: "By 07:00 the ranking change is merged and deployed (likely by
   02:00-03:00 at today's pace) and precision is measured. Not done by then:
   the UI copy, which needs your call on wording."

While he is away:

- Parallel lanes as in `engineering-workflow` §3: no lane waits on one it
  does not depend on.
- T3 child tasks and watched pull requests wake you; they need no
  heartbeat. Background shell jobs wake you when they exit, but a T3 restart
  kills them without a word. While one runs, keep one hourly schedule bound
  to this thread:
  ```json
  {"title": "<effort> wake", "schedule": {"type": "interval", "everyMs": 3600000},
   "prompt": "Re-read <effort file>. Restart any wait under Running tasks that is gone, judge the milestones, and delete this schedule once no shell job runs."}
  ```
  `schedule_task` with that input. Record the returned task id under
  "Running tasks" and remove it with `delete_scheduled_task` once no shell
  job runs.
- A missed milestone: change approach, don't wait for morning. Two rounds with
  no new evidence on one problem: stop that lane and re-route it.

When he returns, the report leads with what is blocked on him, then each
milestone met or missed with its evidence.

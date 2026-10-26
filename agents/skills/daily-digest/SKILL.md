---
name: daily-digest
description: Sebastian's 18:00 digest across all agent sessions - what landed, what waits on him, what is late. Use when the daily schedule fires or he asks for the digest.
disable-model-invocation: true
---

# Daily digest

One message, so Sebastian never opens sessions to see where things stand.
Read-only apart from step 5: nudge no thread, fix nothing.

1. Run `~/dotfiles/bin/agent-messages digest`. It reads T3's database and
   every effort file for the last 24 hours. Every item in the digest comes
   from its output.
2. Check each item at its source before listing it: open the effort file or
   thread it names and read its Next and newest messages. An effort that
   waits on a scheduled run is not late; one that waits on Sebastian belongs
   under "Waits on you"; one whose blocker is its own running work does not.
   A pull request counts as handed over only when its thread says so. A
   decision he already gave (Approved, Decisions, his later messages) is not
   waiting. Take times from the reader or T3's records, never estimate them.
3. Write the digest in this thread, one or two sentences per item, each
   with its link (`[title](t3-thread://v1/<threadId>)`, the pull request URL
   or the effort path), in this order:
   - **Waits on you:** pending questions with the agent's recommendation
     (`recommended_options`, or its "I recommend" in the question), efforts
     waiting on him with the blocker, pull requests handed over.
   - **Late:** overdue milestones, stalled efforts, tasks recorded as running
     that have ended, failed runs not resent (`resent_in_thread_id` empty),
     each with what step 2 found.
   - **Landed:** efforts done, pull requests merged.
   - **Running:** one line of counts.
   Leave out an empty section. Nothing at all: one line, "Nothing needs you;
   <n> efforts running."
4. Reader errors and entries under `errors` go last, one line per kind.
5. T3 runs each scheduled task in a fresh worktree of `~/dotfiles` and
   leaves it or its branch behind. Remove those of earlier digest and weekly
   runs, never other threads': worktrees and branches named
   `t3/write-daily-digest*` or `t3/run-weekly-review*`, except this run's.
   `git -C ~/dotfiles worktree remove <path>`, then `git -C ~/dotfiles
   branch -d <branch>`; both refuse uncommitted or unmerged work, so leave
   those and list them.

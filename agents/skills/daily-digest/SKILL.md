---
name: daily-digest
description: Sebastian's 18:00 digest across all agent sessions - what landed, what waits on him, what is late. Use when the daily schedule fires or he asks for the digest.
disable-model-invocation: true
---

# Daily digest

One message, so Sebastian never opens sessions to see where things stand.
Read-only: nudge no thread, fix nothing.

1. Run `~/dotfiles/bin/agent-messages digest`. It reads T3's database and
   every effort file for the last 24 hours. Every item in the digest comes
   from its output.
2. Check each item at its source before listing it: open the effort file or
   thread it names and read its Next and newest messages. An effort that
   waits on a scheduled run is not late; one that waits on Sebastian belongs
   under "Waits on you". A pull request counts as handed over only when its
   thread says so; one still being worked is not waiting on him.
3. Write the digest in this thread, one line per item, each with its link
   (`[title](t3-thread://v1/<threadId>)`, the pull request URL or the effort
   path), in this order:
   - **Waits on you:** pending questions with the agent's recommendation when
     it gave one, blocked efforts with the blocker, pull requests handed over.
   - **Late:** overdue milestones, stalled efforts, tasks recorded as running
     that have ended, failed runs, each with what step 2 found.
   - **Landed:** efforts done, pull requests merged.
   - **Running:** one line of counts.
   Leave out an empty section. Nothing at all: one line, "Nothing needs you;
   <n> efforts running."
4. Reader errors and entries under `errors` go last, one line per kind.

Good: "**Waits on you:** [Kimsufi hunter](t3-thread://v1/…): merge #161?
Gate passed 14:20; the agent recommends merging."

Bad: "There are 3 pending items across your sessions."

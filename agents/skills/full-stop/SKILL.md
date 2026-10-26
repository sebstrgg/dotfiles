---
name: full-stop
description: Take a change all the way to ready-to-merge without Sebastian, then stop before merging so he can. Use when he says "full stop", "get it ready but don't merge", "I'll merge it myself", or "take this over" for work he wants to look at last.
---

# Full stop

`full-send` with one difference: never merge or deploy. Own the work until
the pull request passes the merge gate, then hand it to Sebastian.

- Follow `full-send` steps 1 to 5 and its merge gate, including
  `review-loop` for anything expensive to get wrong. Keep fixing, proving and
  answering reviews until the gate passes; CI failures, bot findings and
  human comments are yours to handle.
- Do not bother Sebastian until the pull request is ready or you are hard
  blocked; then ask through the question tool, so the thread waits on him.
- The ready message: what changed and why in two lines, the proof, the
  risks of merging today, what you could not confirm, and the pull request
  link. Keep watching it (`babysit-pr`): a new commit on the base, a new
  review or a red check puts the work back on you until it is ready again.

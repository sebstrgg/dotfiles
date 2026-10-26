---
name: babysit-pr
description: Get an open pull request to green and mergeable - checks, review comments, bots, conflicts. Use when a pull request is open and waiting on CI or review, or when Sebastian says "watch", "babysit" or "keep an eye on" a PR.
---

# Babysit a pull request

- In T3 Code, link the pull request to the thread (`link_pull_request`) and
  `watch_pull_request`, then end the turn: T3 wakes you when checks finish,
  someone comments or the branch conflicts. Never poll with sleep loops or
  `gh pr checks --watch`. Outside T3, one background `gh pr checks --watch`
  whose exit wakes you.
- On each wake, act only on what is newer than your last push:
  - A failing check: read its log. Fix a real failure locally, push once with
    everything batched. A flake is a bug with a cause: find it or report it;
    a rerun proves nothing.
  - A bot or human finding: check it against the code. Fix what is right,
    reply with a written reason where it is wrong. Review feedback never
    grows the pull request beyond its original goal; file the rest.
  - A conflict or a moved base: rebase, `--force-with-lease`, prove again
    if the merge changed behaviour.
- Another merged change already does this work: stop and ask before closing
  the pull request.
- Comments you post on Sebastian's behalf say which model wrote them.
- Done when the merge gate in `full-send` passes, or when the pull request
  merges or closes. Then `unwatch_pull_request`. Stopping early: unwatch
  first and say why.

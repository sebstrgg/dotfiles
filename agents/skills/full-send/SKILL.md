---
name: full-send
description: Finish a change end to end with no further attention from Sebastian - prove it, open and babysit the pull request, merge, deploy, report. Use when he says "full send", "ship it", "get this landed" or "merge it when it's green", or hands over a change he won't watch.
---

# Full send

Sebastian is not watching this thread. Your updates go unread until long
after you stop, so own the work from its current state to merged, deployed
and verified. If he did not clearly ask for this, don't assume this much
autonomy: follow `engineering-workflow` as usual.

He has granted: merging the pull request when the merge gate below passes,
deploying to his own infrastructure, and `--force-with-lease` on the pull
request's own branch after a rebase. Nothing in this skill widens what the
global instructions reserve for him.

## Flow

1. Finish the change and its tests.
2. Prove it with `prove-it`. A change you could not prove does not merge.
3. Expensive to get wrong (security, auth, secrets, persisted data,
   migrations, money, concurrency, public contracts): `review-loop` first.
4. Open or update the pull request (body per `pr`, with the proof) and keep
   it a draft while iterating. Mark it ready once, on the release commit
   (`engineering-workflow` step 4).
5. `babysit-pr` until the merge gate passes.
6. Merge, deploy where the change ships to a running service, and prove the
   new build is the one running and doing what it should.
7. Tracked effort: a fresh `verify` from the other model family.
8. Report, unwatch the pull request, and leave nothing running.

## Merge gate

All of these, checked from the live pull request, not from memory:

- The proof covers every change in the diff.
- Every required check is green on the current head. Read the full
  `gh pr checks` listing; a red check blocks even when it looks unrelated.
- Every review bot has finished; each finding is fixed, or dismissed with a
  written reason in the thread.
- No human review requests changes.
- The branch contains the default branch's tip and GitHub reports it
  mergeable.

## Asking Sebastian

Ask only when you cannot continue alone: a reserved action, missing access,
or a decision that changes the outcome. Use the question tool so the thread
shows it is waiting, and put everything in the question: the pull request
link, what blocks you, and the options with your recommendation first. While
you wait, do everything that does not depend on the answer. Without access
you need, take the safe path and say so.

## Report

Blocked on Sebastian (nothing, ideally), then the pull request and merge
commit, where it runs, the proof, and anything you could not confirm.

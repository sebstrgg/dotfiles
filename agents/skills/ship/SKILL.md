---
name: ship
description: Carry a finished change through its pull request to merged and deployed, or to ready-to-merge when Sebastian merges himself. Use when a change is ready for a pull request, or he says "ship it", "full send", "land it", "get this merged", "full stop", "get it ready but don't merge", "I'll merge it myself" or "take this over".
---

# Ship

Two modes:

- **Land** (the default; "ship it", "full send", "land it"): merge and deploy
  yourself once the merge gate passes.
- **Ready** ("full stop", "don't merge", "I'll merge it myself"): stop at a
  pull request that passes the merge gate and hand it to Sebastian.

He is not watching either way. Report only at the mode's end or on a real
block. Granted in both modes: pushing, opening and updating the pull request,
`git push --force-with-lease` to its own branch after a rebase. Land adds
merging when the gate passes and deploying to his own infrastructure. Nothing
here widens what the global instructions reserve for him.

## Steps

Start every `git push` and `gh` command with `cd /absolute/checkout &&`:
otherwise Codex hides its working directory from the CI tripwire.

1. Prove the change (`prove-it`). A change you could not prove does not merge.
   Expensive to get wrong (security, auth, secrets, persisted data,
   migrations, money, concurrency, public contracts): run the review loop in
   `delegate` first.
2. One pull request per branch. Reuse an open one:
   `gh pr list --head <branch> --json number,url`. Otherwise:
   ```sh
   git fetch origin && git diff --stat origin/<base>...HEAD  # only this change's files
   gh pr list --state merged --limit 10 --json title          # the title style to match
   gh pr create --draft --base <base> --title "<title>" --body-file .scratch/<effort>/pr.md
   ```
   Then call `link_pull_request` with its URL.
3. Iterate in the draft. Drafts run only fast checks; every push to a ready
   pull request starts a full run on the shared CI farm and cancels the last.
4. Release once: commit everything, run
   `~/dotfiles/bin/effort-gate release "<why this commit is the release>"`,
   push, then `gh pr ready <n>` as its own command.
5. `babysit-pr` until the merge gate passes.
6. Ready mode: `unwatch_pull_request`, so the thread lands in his inbox, then
   send the ready message. Land mode: merge, deploy and prove it live.
7. Tracked effort: a fresh `verify` through `delegate`. Then clean up
   (`engineering-workflow` close) and report.

## Title and body

The title says what changes for the user, as an imperative sentence in the
style of the merged titles from step 2. Use a `feat:` style prefix only when
those titles do.

The body opens with the problem in Sebastian's words, then what behaves
differently, then the proof and the risk. A reviewer knows why from the first
two lines. Leave out the inventory of files, functions and tests: the diff
shows it.

```markdown
## Problem
<one or two sentences from the request or issue; link the issue>

## Change
<what behaves differently now; a diff-sketch, call tree or Mermaid diagram
only when it says more than a sentence>

## Proof
<before and after: screenshots or a recording for UI, the failing then
passing command for logic, live readback for a service>

## Risk
**Door:** one-way | two-way. **Blast radius:** <one word>. <rollback in one line>

<when the review loop ran: rounds, reviewer model, verdict>

Written by <model> in <Claude Code | Codex> on behalf of Sebastian.
```

`<model>` comes from `t3_thread_configuration` called with no arguments (its
`model` field). Outside T3, use the model your system prompt names; if it
names none, write only the runtime.

Bad: an inventory with no problem and no proof.

```markdown
## Summary
- Added `retryPolicy.ts`
- Updated `client.ts` to use the retry policy
- Added tests and updated the README
```

Good:

```markdown
## Problem
Price checks failed silently when OVH rate-limited us, so an in-stock server
showed "unavailable" for up to an hour (#158).

## Change
A rate-limited check waits for the `Retry-After` delay, retries, and shows
"checking" until it succeeds or fails for real.

## Proof
Before: replaying the recorded 429 shows "unavailable". After: "checking",
then "in stock". Screenshots below.

## Risk
**Door:** two-way. **Blast radius:** price checks. Revert the merge commit.
```

## Merge gate

Read the live pull request right before merging or handing over, never from
memory:

```sh
gh pr checks <n>
gh pr view <n> --json isDraft,mergeable,mergeStateStatus,reviewDecision,headRefOid
git fetch origin && git merge-base --is-ancestor origin/<base> <headRefOid>
```

It passes when all of these hold:

- Every `gh pr checks` row is `pass` or `skipping`, and none is pending. A
  red check blocks even when it looks unrelated or known.
- `isDraft` is false, `mergeable` is `MERGEABLE`, `mergeStateStatus` is
  `CLEAN` or `HAS_HOOKS`, `reviewDecision` is not `CHANGES_REQUESTED`.
- `merge-base --is-ancestor` exits 0: the head contains the base's tip.
- `babysit-pr`'s thread query returns no unresolved thread, and every review
  bot has posted on the current head.
- The proof covers every change in the diff.

## Merge and deploy (land mode)

```sh
git log origin/<base> --first-parent -5 --format=%s
gh pr merge <n> --squash --match-head-commit <headRefOid>
git push origin --delete <branch>
```

Use `--merge` instead of `--squash` when those subjects read
`Merge pull request #…`. Don't pass `--delete-branch`: in a worktree it
fails when it tries to switch branches.

Deploy once per release, to his own infrastructure:

- Know the rollback before you start.
- Connect source revision, tested artifact and running version, with
  immutable artifact references.
- Restart every process that runs the changed code.
- Show that the running version is the merge commit.
- Check the user's or operator's outcome live. For an intermittent failure,
  watch long enough that it would have shown.

## Asking

Ask only when you cannot continue alone: a reserved action, missing access,
or a decision that changes the outcome. Use the question tool, and put
everything in it: the pull request link, what blocks you, and the options
with your recommendation first. While you wait, do everything that does not
depend on the answer.

## Ready message and report

Good:

```markdown
**Ready to merge:** wl7r/kimsufi-hunter#161 (gate passed 14:20).
Price checks no longer show "unavailable" while OVH rate-limits us: they
wait, retry and show "checking".
Proof: before and after screenshots in the pull request.
Risk: two-way, price checks only.
Not confirmed: a real 429 in production (replayed from a recording).
```

Bad:

```markdown
I've finished the work! I added a retry policy, updated the client and wrote
tests, and everything passes. Let me know if you'd like any changes.
```

The land-mode report has the same shape. It adds the merge commit, where the
change runs, and the live proof.

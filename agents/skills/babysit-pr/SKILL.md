---
name: babysit-pr
description: Get an open pull request to green and mergeable - checks, review comments, bots, conflicts. Use when a pull request is open and waiting on CI or review, or when Sebastian says "watch", "babysit" or "keep an eye on" a PR.
---

# Babysit a pull request

## Start

1. Read what is already there. T3 wakes you only for new events, so existing
   findings never come back on their own:
   ```sh
   gh pr checks <n>
   gh pr view <n> --comments    # top-level comments and bot summaries
   gh api graphql --paginate -F owner=<owner> -F repo=<repo> -F n=<n> -f query='
     query($owner:String!,$repo:String!,$n:Int!,$endCursor:String){
       repository(owner:$owner,name:$repo){pullRequest(number:$n){
         reviewThreads(first:100,after:$endCursor){
           pageInfo{hasNextPage endCursor}
           nodes{id isResolved path line
             comments(first:50){nodes{databaseId author{login} body}}}}}}}' \
     --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not)'
   ```
   Act on everything open, as in "Each wake".
2. Call `link_pull_request`, then `watch_pull_request`, each with the pull
   request URL. End the turn. T3 wakes you when a check fails, the required
   checks pass, someone comments or reviews, or the branch conflicts.
   - Never poll: no `sleep` loop, no `gh pr checks --watch`, no
     `gh run watch`.
   - Outside T3, use one background `gh pr checks <n> --watch` whose exit
     wakes you.
   - A delegated child cannot watch: report the URL to the parent, which
     watches.

## Each wake

Run step 1's reads again and act on everything still open:

- **A failing check:** read the log with
  `gh run view <run-id> --log-failed`. Fix a real failure locally. A flake
  is a bug with a cause: find it or report it. A rerun proves nothing.
- **A finding from a bot or a person:** check it against the code. Fix what
  is right. Reply with a reason where it is wrong. Review never grows the
  pull request beyond its original goal: file the rest with
  `gh issue create` and link the issue in your reply.
- **A conflict or a moved base:**
  `git fetch origin && git rebase origin/<base>`. Prove the change again if
  behaviour changed, then `git push --force-with-lease`.
- **Pushing fixes:** batch them into one commit. For a ready pull request,
  take the commit through `engineering-workflow` step 4 (local checks, then
  `effort-gate release`) before you push.
- **Settling a thread:** resolve each thread you fixed or answered:
  `gh api graphql -F id=<thread id> -f query='mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}'`.

## Replies

The GitHub account that posts is shared by every agent, so each comment and
reply opens with a signature line:

```markdown
**<model>** · <Claude Code | Codex> · on behalf of Sebastian
```

Get `<model>` from `t3_thread_configuration` called with no arguments (its
`modelSelection.model`). Then
say what you did and where (the commit), or why you won't, in one or two
sentences.

- Reply in a thread:
  `gh api repos/<owner>/<repo>/pulls/<n>/comments/<databaseId>/replies -F body=@reply.md`.
- Top-level comment: `gh pr comment <n> --body-file reply.md`.

Good:

```markdown
**Claude Opus 5.5** · Claude Code · on behalf of Sebastian

Fixed in 3f2a91c: the retry stops after three attempts.
```

```markdown
**gpt-6.1-sol** · Codex · on behalf of Sebastian

Not changing this: `price` is never null here, because `parseOffer` rejects
offers without one (src/offers.ts:42).
```

Bad: no signature, no commit, no reason, and flattery.

```markdown
Great catch! Fixed.
```

## Done

- Done when `ship`'s merge gate passes, or when the pull request merges or
  closes. Then call `unwatch_pull_request`, so the thread returns to
  Sebastian's inbox.
- Stopping early: unwatch first and say why.
- Another merged change already does this work: ask before closing the pull
  request.

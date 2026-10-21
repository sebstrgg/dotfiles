# Delivery

## Branches and pull requests

- One worktree, branch and port block per task.
- Open pull requests as drafts and keep them in draft while iterating: drafts run
  only fast checks, and every push to a ready PR starts a full run on the shared
  CI farm and cancels the previous one. Batch commits locally, push in a few
  meaningful steps, and mark the PR ready once, when the change is complete and
  verified.
- Before pushing, run the CI job's fast steps (lint, format, type and
  repository-root checks) locally across the whole repository, not only the
  touched files.
- Merge one at a time into the integration branch through its PR, with green CI
  on a head that contains the integration tip. Read the full `gh pr checks`
  listing, not a watch exit code; a red check, even a known infrastructure
  failure, blocks the merge until fixed.
- Write PR bodies with `pr`.

## A secret in git history

- Rewrite with `git filter-repo`, push with `--force-with-lease`, and keep the
  pre-rewrite backup (a bundle) in `.scratch/<effort>/`: out of git, and
  removed with the effort. The report names it, and asks to rotate the secret.
- The agent's own session record (`~/.claude/projects`, `~/.codex/sessions`)
  keeps the earlier content of every file it edits: the report names it among
  the places the secret remains.

## Shared areas

- When another session owns an area, split by app or file, announce merges,
  sequence migrations, and leave that session's work and effort file to it.
- Coordinate with a local Claude session through `SendMessage`, otherwise
  through the effort files, not through Sebastian.

## CI, data and spend

- Development and CI run on recorded answers. Paid calls go through a budgeted
  path with an explicit limit; report spend exactly.
- Personal data used in an evaluation stays in a private folder outside the
  repository; check for it before every push.

## Deploy

- Deploys to Sebastian's own infrastructure proceed within the task. Connect
  source revision → tested artifact → running version, use immutable artifact
  references, and know the rollback before deploying.
- After merging or deploying, restart every process that runs the changed code
  and prove the new build is the one running. Then verify the user or operator
  outcome live; for intermittent failures, observe long enough to trust the
  fix.

## Clean-up

- Worktree: confirm `git -C <path> status --porcelain` is empty and the work is
  merged or pushed, then `git worktree remove <path>`, `git worktree prune`, and
  delete the merged local branch. Report a worktree holding unintegrated work
  with its path, branch and state.
- Docker: `docker compose -p <project> down --volumes --remove-orphans` for
  disposable test stacks, plus the images, volumes and networks created for
  them. Long-lived development data stays; name it in the report.
- Backups and rollbacks: keep one verified rollback per service; once a new
  deploy is verified, delete the older ones this work made.
- Clean up only what this work created; report another session's leftovers to
  that session or to Sebastian.

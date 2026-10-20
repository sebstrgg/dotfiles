# New project baseline

Apply when creating a project or onboarding an existing repository. Include
the baseline in its spec and tickets, adapt it to the project's language and
product, and complete it as part of the requested project setup.

## Repository and structure

- Create Sebastian-owned project repositories in the `wl7r` GitHub organization.
  For an owned repository elsewhere, include transfer to `wl7r` in onboarding.
  Identify the exact source and destination before the mutation, check existing
  authorization and active work, and preserve collaborators, integrations and
  references. After transfer, verify ownership, access, remotes and CI.
- Keep third-party upstreams and repositories Sebastian does not own outside
  this transfer rule. Existing project work outside an onboarding task should
  surface ownership drift and a concrete migration proposal without silently
  transferring unrelated repositories.
- Resolve repository visibility and deployment intent during grilling. The
  existing SNAS farm admits private Sebastian-owned repositories only. Public
  repositories and outside contributors need a separately authorized, isolated
  CI path; keep visibility and isolation decisions explicit.
- Use native ecosystem structure, pinned dependency installation, reproducible
  development commands and a clear verification entry point. Put purpose,
  navigation, data boundaries and operating decisions in the project's existing
  documentation layout. Keep credentials and private evaluation data out of Git.
- Gitignore `.scratch/` so effort files stay local.
- A project with a UI starts with its design system, `DESIGN.md` and lint
  checks from the [design reference](design.md), before the first screen.

## Reuse the canonical infrastructure

Read the `wl7r` skill and the active personal-infra checkout's `core.md` before
infrastructure work. With no active checkout owning that work, use
`~/code/personal-infra`. These are the current canonical entry points:

- `runbooks/ci-runner-farm.md` and its `change.md` leaf: repository admission,
  runner isolation and the shared workflow interface.
- `.github/workflows/build-push.yml`, `record-tested-images.yml` and
  `promote-tested-images.yml`: reusable container build and artifact promotion.
  Inspect their contracts and pin a reviewed revision when applicable.
- `runbooks/zot-registry.md`: project-scoped registry access.
- `playbooks/service-onboarding.md`: internal web service deployment through
  existing ingress, identity and private networking.

Follow those sources for current configuration and procedures. Reuse relevant
maintained templates and shared workflows; adapt language-specific checks and
packaging. If a suitable template is missing, implement the smallest complete
baseline for this project and propose reusable extraction when justified.

## Working CI/CD is part of setup

- Wire the repository's real check commands into CI, with distinct draft and
  ready-PR behavior and required checks appropriate to the change. Verify the
  actual repository enforcement; a workflow file alone does not protect merges.
- For farm tenants, complete runner admission, verified lockfile installation,
  fork refusal and project-scoped registry credentials through the canonical
  procedures. Confirm the job's environment has the required tools and access.
- For deployable services, connect the verified build artifact to the intended
  environment, with scoped deployment access, configuration handling, a real
  application check and a documented recovery path. Container deployments use
  immutable image references. Projects without a hosted service use the
  appropriate package or release path instead.
- Honor the global authority rules for provisioning, publication, purchases,
  DNS and live changes. Investigate reachable prerequisites and finish authorized
  setup. Identify any remaining approval or missing access precisely; do not
  report a merely prepared pipeline as operational.

Setup is complete when the actual repository runs its relevant pipeline
successfully and the intended authorized release or deployment can be verified
from source revision through artifact to user outcome. Exercise recovery where
the consequences require it, record the evidence in the project's canonical
operating documentation, and identify any unverified delivery stage.

---
name: engineering-workflow
description: Apply Sebastian's engineering framework throughout a task. Route new projects and feature changes through grilling, specs, tickets, implementation and verification; select the relevant playbook when intent, evidence or phase changes.
---

# Engineering workflow

Sebastian authorizes automatic selection and application of installed Matt
Pocock playbooks, including manual-only slash commands. Use native skill
invocation when available; otherwise read and apply the installed `SKILL.md` as
a nested playbook. Reading its name or mentioning it is not execution. The
adaptations below express Sebastian's preferences; global authority, safety and
review rules still apply.

## 1. Route throughout the session

At intake, a phase boundary, changed requirements, or evidence that invalidates
the current approach, identify the next applicable playbook and apply it without
waiting for a slash command. On resume or handoff, recover the current phase,
decisions and evidence from the effort's existing ledger and artifacts.

- Every new project, new feature or changed feature follows the feature path
  below. Small features still get a concise spec and at least one ticket.
  Existing approved artifacts can satisfy a phase when they cover the current
  request; update affected artifacts when the scope changes.
- Questions, status, reviews, mechanical edits and repairs that restore agreed
  behavior use their relevant focused workflow. A repair that introduces new
  behavior or a new product decision enters the feature path.
- A subagent or dispatched worker with a bounded brief executes the brief
  directly. The orchestrator owns the full path and gives each worker the
  applicable playbook and context pointers.
- Read `ask-matt/SKILL.md` once when routing substantive work, then the selected
  playbook and required references. Prefer `~/.agents/skills/<name>/SKILL.md`;
  resolve missing names from runtime skills or the Matt Pocock plugin. If a
  required playbook remains unavailable, report the specific gap and continue
  independent work without claiming that phase complete.

## 2. Feature path

For a new project or repository onboarding, also apply
[New project baseline](references/new-project.md) while defining the spec and
tickets. Project setup and working CI/CD are part of delivery.

| Phase | Playbook | Evidence required to advance |
| --- | --- | --- |
| Resolve intent | `grilling`; `grill-with-docs` when project decisions need a durable home | Relevant facts are investigated and Sebastian has confirmed shared understanding. Reuse settled answers; ask only unresolved decisions. |
| Resolve a design needing runnable or visual evidence | `prototype` when needed | The experiment answers the question and Sebastian selects any unresolved design direction. |
| Define the outcome | `to-spec` | A durable spec captures agreed behavior, boundaries, decisions, verification and exclusions. |
| Define delivery slices | `to-tickets` | Tickets have observable acceptance criteria and genuine blocking edges; Sebastian has approved the breakdown. |
| Deliver the spec | `implement-spec` | All tickets in the authorized scope are implemented and integrated, with evidence for every acceptance criterion and remaining graph work identified. |
| Verify and review | The applicable `tdd` and `code-review` steps, plus the global review rule | The actual user or operator outcome is demonstrated, confirmed findings are fixed and rechecked, and completion evidence applies to the final changes. |

Invoke other playbooks when the work calls for them: diagnosis for a resisting
failure, research for an unresolved factual question, domain modeling for
ambiguous terminology, and design or architecture work for a consequential
structural decision. Return to the affected spec and tickets after resolving it.
Use `session-handoff` at the global handoff boundary.

## 3. Apply playbooks within the task's authority

Briefly name a selected workflow and its purpose when changing phase. Apply its
steps and inspect the resulting artifacts and evidence. Keep routine selection
and technical implementation decisions with the agent.

Already supplied or approved decisions satisfy the matching upstream
checkpoints. Preserve shared-understanding, design-selection, spec verification
and ticket-breakdown checkpoints; combine compatible reviews into one concrete
proposal. Explain verification choices through observable behavior so Sebastian
can judge the outcome. Prepare complete local drafts first. Keep artifacts
proportionate: a small feature may need one short spec and one complete ticket.

Use the project's canonical artifact locations; otherwise use
`.scratch/<feature>/spec.md` and one file per ticket in
`.scratch/<feature>/issues/`. Unapproved tickets remain drafts. Missing tracker
setup does not block local drafting or authorize provisioning a tracker.

`implement-spec` coordinates the graph within the requested scope. A request to
implement one ticket authorizes that ticket; retain the remaining graph as
context and report its state. Apply the global delegation rule:
execute a single bounded ticket directly in the task worktree when that is
sufficient, and delegate independent lanes when it creates value. Name the
implementation playbooks in each brief, respect active ownership, integrate
serially, and independently verify workers' completion claims. Reuse completed
verification when it still covers the final state.

Automatic skill selection does not expand action authority. Issue publication,
messages, repository changes at the hosting provider, pushes, PRs, merges and
deployments follow the current task's authorizations and global approval rules.
Check existing authorization before asking again. A discussion stays a
discussion until implementation is requested.

## 4. Uphold the framework and correct course

Before substantive implementation, check the relevant context, tools and access
in the executing environment, and establish how the intended outcome will be
proved. At phase transitions, compare the actual work with the agreed spec,
constraints and global standards. Keep the phase, artifact pointers, decisions,
unresolved gaps and next step in the existing effort ledger.

When a prerequisite, standard or acceptance criterion is unmet, investigate and
correct it within scope, then verify the correction. Return to grilling when
intent forks; revise the spec and affected tickets before continuing changed
behavior. Reopen completion when new evidence contradicts it. Preserve the
accepted quality bar; propose explicit changes when the framework itself is
causing a poor outcome.

After substantial rework, an escaped defect or repeated steering, apply `retro`.
Prefer repairing an existing tool, check or canonical source over adding
instructions. Complete authorized improvements and identify concrete proposals
outside scope. Continue authorized work until the requested outcome is proved
or a real decision or evidenced blocker requires Sebastian.

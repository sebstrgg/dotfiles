---
name: engineering-workflow
description: Select Matt Pocock workflows automatically for planning, design decisions, specs, tickets, implementation, debugging, research, review, and handoffs. Use at task intake and when the work changes phase; handle small, settled edits directly.
---

# Engineering workflow

Sebastian authorizes automatic selection and application of the installed Matt
Pocock playbooks, including those whose upstream metadata makes their slash
commands manual-only. Read those files as nested playbooks when selected here;
the user does not need to invoke their command. Upstream procedures supply the
workflow; the scope and checkpoint rules below express Sebastian's preferences.

## 1. Select the current phase

At intake or a phase boundary, use the current request, prior decisions, and
existing project artifacts to identify what remains unresolved.

- For a small, settled edit or straightforward factual answer, work directly.
  A task does not need an interview, spec, or tickets just because it is code.
- For substantive work, read the installed `ask-matt/SKILL.md` routing reference
  once, then read the selected playbook and the references it requires. Prefer
  the shared library at `~/.agents/skills/<name>/SKILL.md`, available to both
  Claude and Codex. If absent, resolve the name from the runtime's installed
  skills or Matt Pocock plugin. Report a missing required playbook; do not
  claim to have used it or silently substitute a homemade workflow.

Use the upstream routes with these entry and completion conditions:

| Current need | Playbook | Phase complete when |
| --- | --- | --- |
| Material goals, constraints, or design tradeoffs remain unresolved | `grilling`; `grill-with-docs` when durable domain decisions belong in the project | Facts are investigated and Sebastian has resolved the consequential decisions |
| A design question needs runnable evidence or visual alternatives | `prototype` | The question has evidence and Sebastian has selected any unresolved design direction |
| An agreed substantial change needs a durable implementation contract, especially across sessions | `to-spec` | The spec captures agreed behavior, boundaries, and test seams |
| An agreed effort needs multiple independently verifiable delivery slices | `to-tickets` | Complete ticket drafts define acceptance criteria and real blocking edges, ready for breakdown review |
| A spec, ticket, or bounded feature is ready and implementation is authorized | `implement`, with its applicable `tdd` and `code-review` steps | The requested behavior is verified and the change reviewed |

Use `ask-matt` for the other routes: difficult bugs, research, domain language,
architecture, incoming-issue triage, large unresolved efforts, and handoffs.
Choose from the actual situation, not a keyword alone. Existing decisions and
artifacts let work enter at any phase; the idea-to-ship flow is not a mandatory
pipeline. Read only the playbooks needed for the current phase.

## 2. Apply the selected playbook

Briefly name the workflow and the need it addresses, then do the work. Ask for
decisions, not permission to select a skill. Investigate discoverable facts
yourself; focus grilling on material uncertainty and conflicting assumptions.

Already supplied or approved decisions satisfy the matching upstream
checkpoints. Keep new consequential decisions with Sebastian. Complete local
drafts before asking for spec or ticket approval; identify any unresolved test
seam in the draft. Mark unapproved ticket drafts as drafts, not ready-for-agent.
Use the project's canonical artifact location; without one, use
`.scratch/<feature>/spec.md` and `.scratch/<feature>/issues/`. Missing tracker
setup is a reason to draft locally, not to provision a tracker or labels.

Apply the current task's authority throughout. Selecting a publishing workflow
does not authorize issue creation, messages, pushes, PRs, deployment, or live
changes. Prepare the reviewable result locally and seek any still-required
approval only for the actual external action. Explicit permission already
given for that action remains valid. A discussion stays a discussion until
implementation is requested.

## 3. Verify and continue

Check the phase's completion condition against the actual artifacts or evidence.
For authorized delivery, continue to the next applicable phase without waiting
for another slash command. If a material decision remains, present the evidence
and ask the decision-ready question before dependent work. Finish when the
requested outcome is delivered, not when every library workflow has run.

# RTK for local validation

Use RTK automatically for supported local test, lint, and type-check commands
when their output would otherwise be verbose. Preserve the project's runner,
arguments, environment, and exit status. Examples: `uv run rtk pytest`,
`rtk cargo test`, `rtk vitest run`, and `rtk ruff check .`.

Keep source reads, `rg`, diffs, structured output, live operations, and commands
whose exact output is the evidence on their native path. Short commands such as
`git status --short` already produce compact output. Use the original command
when RTK is absent or does not support its runner; avoid generic summarizers.

For sandboxed execution, set `RTK_TEE_DIR` to a writable per-task temporary
directory so raw output can be saved without writing outside the sandbox.
RTK's saved raw-output file is the diagnostic source when a summary is ambiguous,
fails, or omits details needed to verify a result. Read it directly; if missing or
truncated, capture the native output on the next safe run. Use only the log named
by the current invocation; an older log is not evidence of the current run. A compact summary
alone does not prove that the intended tests ran. `rtk gain` reports estimated
command-output savings, not total session cost.

This setup uses agent instructions, with no global command-rewrite hook or shell
alias. Keep telemetry off and local raw-output retention enabled. Routine task
execution must not run `rtk init`, which installs a broader routing policy.

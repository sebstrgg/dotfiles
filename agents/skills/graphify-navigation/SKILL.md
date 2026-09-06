---
name: graphify-navigation
description: Use an existing Graphify graph for unfamiliar codebase architecture, cross-file dependency tracing, or change impact analysis before broad repository search. Use ordinary search for known-file lookups and local edits. Explicit graph creation and semantic extraction use the graphify skill.
---

# Graphify navigation

Use the graph to locate evidence for the current task. Repository instructions
and current source files establish behavior; graph relationships are search leads.

## 1. Check coverage

Start at the relevant repository root, after reading its entrypoint instructions.
If `graphify-out/graph.json` or the installed `graphify` CLI is absent, continue
with scoped `rg` and source reads. A missing graph does not block the task or
implicitly request installation or indexing.

Check freshness once before consulting the graph, and again if the checkout
changes during the task. Run the bundled helper, replacing `SKILL_DIR` with this
skill's directory:

```sh
python3 SKILL_DIR/scripts/status.py .
```

The helper uses the installed Graphify CLI's Python interpreter and native
detector, without package-manager locks, downloads, or graph writes. It compares
the current corpus against the manifest and reports code and semantic coverage
separately. An AST
refresh does not establish that documentation has been semantically indexed.
For code questions, `code_coverage: current` supports normal navigation even when
documentation is unindexed. Partial coverage still permits one query to locate
candidate source files; reconstruct the relevant connections from current
sources rather than relying on stale edges. Pending files may include formats
that the extractor cannot represent, so rebuilding is not guaranteed to clear
the count. For documentation questions with stale semantic coverage, search
current documents directly. Missing or invalid metadata means unknown coverage;
use source search rather than assuming the graph belongs to this checkout.
If the installed environment cannot run the helper, fall back to source search.

During an authorized code change, a local AST refresh may be useful when the
task needs repeated graph
queries: `graphify update .`. Inspect its result and rerun the freshness check;
preserve any existing semantic graph and investigate a shrink refusal before
using `--force`. For new graphs, media, or semantic rebuilds, use the `graphify`
build skill only when that work is within the user's requested scope.

## 2. Query narrowly

For current coverage, start with one bounded query using symbols or domain terms
from the task or repository entrypoint:

```sh
graphify query "relevant symbols or concepts" --budget 1500
```

Use `graphify path "A" "B"` for a connection, or `graphify affected "symbol"`
for change impact. Read source references from the result. If the first query
misses, refine once using vocabulary observed in sources or graph output, then
continue with scoped search. A missing edge does not prove no dependency exists.
Load a report only when its broad architectural summary serves the task.

## 3. Verify the answer

Read the current source behind material claims and check the relevant call sites,
configuration, or tests. Distinguish inferred connections from observed ones.
Graph coverage cannot establish exhaustive impact or live infrastructure state.
Complete the user's task from the verified evidence; ordinary navigation does
not write Q&A memory, start watchers, install hooks, or rebuild the corpus.

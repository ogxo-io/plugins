---
name: architecture-advisor
description: "Senior software architect for system design, design patterns, trade-off analysis, and ADRs. Use for choosing between system designs or technologies, reviewing an existing architecture, assessing architectural debt, or writing an ADR; it returns analysis and recommendations, not code changes."
---

# Architecture Advisor

## Host integration

Use the host's actual file, search, shell, browser, and worker tools. Named Claude tools, model settings, effort settings, and tool allowlists in source agent metadata do not configure this host. Permissions and worker availability come from the current session. Read the corresponding source agent markdown as a procedure, ignoring its Claude frontmatter and any statements that missing Write/Edit tools enforce read-only access. Follow the procedure's requested scope yourself.

When delegating, use the available worker tool with a plain task prompt containing the procedure, scope, repository path, inputs, output contract, and requested read-only or edit behavior. A specialist name labels the task; it is not a registered Claude subagent type. If workers are unavailable, perform the same procedure sequentially and disclose that there was no independent worker. Use only exposed tools and report skipped checks or unavailable integrations.

## Run the procedure

1. Read `../../agents/architecture-advisor.md` relative to this skill's directory. Resolve its plugin-root reference paths against `../..` from this directory; read referenced playbooks as the procedure requests them.
2. Establish the user's requested repository, files, time range, diff, logs, or decision. For a diff, run its git/PR command at runtime, inspect the actual output, and stop with an empty-scope report if it contains no changes. Do not stage files to make a diff.
3. Apply the source procedure's workflow and evidence requirements using this host's tools. Keep report-only procedures report-only; implement changes only when the user requested the edit workflow. Security work uses source inspection and defensive validation within the user's scope.
4. Return the procedure's structured report, file/line evidence, checks actually run, and limitations. Tool failures or absent measurements are unavailable evidence, not successful checks.

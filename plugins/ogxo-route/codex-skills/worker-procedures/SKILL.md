---
name: worker-procedures
description: Prepare Codex worker briefs for scout, implementation, tests, verification, bulk logs, and browser scenarios from ogxo-route's reusable procedures.
---

# Codex worker procedures

Each procedure is a shipped worker file. Resolve the plugin root from this
skill's loaded path (two directories above this skill directory), read the
procedure's file, and put its body in the worker brief after the common
routing brief.

| Procedure | Source, relative to this skill's directory | Use for |
|---|---|---|
| scout | `../../agents/scout.md` | Mapping code and answering one question read-only |
| implementer | `../../agents/implementer.md` | One standard task |
| implementer-risky | `../../agents/implementer-risky.md` | One risky task |
| test-runner | `../../agents/test-runner.md` | Running existing tests, builds, linters |
| verifier | `../../agents/verifier.md` | Checking a diff against its task |
| log-extractor | `../../agents/log-extractor.md` | Pulling and filtering bulk logs |
| e2e-runner | `../../agents/e2e-runner.md` | Running browser scenarios |

These files are the Claude Code and Grok Build originals. Adapt them for
Codex as you write the brief:

- Leave out the frontmatter. Its `model`, `tools`, and agent names do not
  configure a Codex worker; the procedure name labels the task, it is not a
  `subagent_type`. These are behavioral instructions, not a tool permission
  boundary; workers have the capabilities of the current runtime.
- Replace `${CLAUDE_PLUGIN_ROOT}` with the plugin root's absolute path, for
  example in the verifier's `scripts/risky-paths.sh` and the
  `scripts/longrun.sh` recipes. Pass each project extra pattern to
  `risky-paths.sh` as a separate quoted argument.
- For long commands, `longrun.sh` works as written; the runtime's own
  asynchronous command API also works. Either way, read the actual exit
  status and output. The Claude Bash timeout and cache-cost figures in the
  procedures are not facts about Codex; keep the call cap and handoff rules.
- Inspect untracked files separately, because `git diff` does not include
  them. Missing runtime support is an uncertainty, not a successful check.

Every procedure ends with `RESULT`, `CHECKS-RUN`, and `UNCERTAINTIES`, and
the verifier also with `VERDICT`; read them before accepting the work.

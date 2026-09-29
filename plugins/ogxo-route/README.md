# ogxo-route

Cost-aware routing for Claude Code. The main session plans and routes; worker subagents pinned to Sonnet or Haiku do scoped work; risky work and reviews stay at Opus or above. The goal is to make Claude Pro and Max usage windows last longer without lowering the bar for risky code. Claude Code only. Requires `jq`.

## Install

```bash
claude plugin marketplace add ogxo-io/plugins
claude plugin install ogxo-route@ogxo
```

It depends on `ogxo-review` (the reviewer), `ogxo-debug` (browser testing for e2e) and `ogxo-specialists` (log-analyst), which install with it.

## How it works

- **Routing skill** (`ogxo-route:routing`): classifies each task as standard, risky, or main-session work and names the agent for it. Risky means security, data or migrations, money, concurrency, public contracts, infrastructure, untested code, or unsure.
- **Session-start summary**: a short version of the policy added to context at startup, resume, clear, and compaction, plus any external agent marked off.
- **Workers:**

| Agent | Model / effort | Job | Tools |
|---|---|---|---|
| `scout` | Sonnet / low | Explore code, return conclusions with file:line | No Write/Edit tools; Bash is unrestricted; instructed to run only read-only commands |
| `test-runner` | Haiku | Run tests, builds, linters; report compactly | No Write/Edit tools; Bash is unrestricted |
| `verifier` | Haiku | Check a diff is the task; flag risky paths and breadth | No Write/Edit tools; Bash is unrestricted |
| `implementer` | Sonnet / medium | Implement a standard task from a plan | Read, Edit, Write, Grep, Glob, Bash |
| `implementer-risky` | session model / high | Implement a risky task | Read, Edit, Write, Grep, Glob, Bash |
| `log-extractor` | Haiku | Pull and filter bulk logs from any shell-reachable source | No MCP tools; no Write/Edit tools; Bash is unrestricted |
| `e2e-runner` | Sonnet / medium | Drive e2e scenarios, classify failures | Read, Grep, Glob, Bash, Skill, and browser MCP servers only |

Haiku has no effort setting, so Haiku workers have none. The Agent tool has no effort parameter, so each worker's effort comes from its own file.

- **External agents:** when `grok-build` or `codex` is installed, the routing sends standard implementation to grok (its bridge script, run from Bash) or `codex:codex-rescue` first, and risky implementation to native workers only. `/codex:review` and `/grok-build:review` set `disable-model-invocation: true`, so only you can run them; the routing suggests them before a PR as an extra pass.
- **Reviews:** risky tasks and every branch before a PR get `ogxo-review:code-review-agent`, on Opus when your session model is below Opus.

## Hooks

All four warn, log, or set the routing marker; none rejects a tool call.

- **anchor** (SessionStart): prints the routing summary. Prints nothing unless `CLAUDECODE=1`, so it stays quiet under Grok Build.
- **generic-warn** (PreToolUse `Agent|Task`): when Explore, general-purpose, or Plan is dispatched without a `model`, adds a note for Claude suggesting `haiku` or `sonnet`. The dispatch has already started on the session model; the note steers the next one.
- **quota-watch** (PostToolUse `Agent|Task|Bash`): when a grok run (the `grok-build:grok-delegate` agent, or a Bash call to `grok-bridge.mjs`) fails with HTTP 402 "usage balance exhausted", marks grok off for routing for 24 hours and adds a note for Claude. Rate limits (429) are ignored. A grok run you ask for by name still goes to grok.
- **dispatch-log** (PostToolUse `Agent|Task`): appends the time, session id, agent type, requested model, whether it ran inside a subagent, and which subagent dispatched it to `dispatches.jsonl` in the plugin's data directory. No prompt text or paths.

## Commands

- `/ogxo-route:external [on|off grok|codex [hours]]`: mark an external agent off for routing when its quota or login runs out (default 24 hours), back on, or show status (with the path of the state file it uses). A grok or codex run you ask for by name is not affected.
- `/ogxo-route:stats [days]`: dispatches per agent and requested model, and how many generic dispatches ran with no model, then the log's path. Keeps 30 days.

## Parallel work

Before running several implementation tasks at once, the routing skill has Claude write a batch table (task, writer, files it may edit, off-limits files, mode).

- **Shared tree (default):** every writer edits your checkout. Tasks run in parallel only on disjoint files, at most two writers at a time, each brief lists its allowed and off-limits files and tells the worker not to run git state-changing commands, and checks re-run on the combined tree before each task is committed.
- **Isolated batch (opt-in, Claude asks first):** one git worktree per task under `.claude/worktrees/`, created from `HEAD` so unpushed commits are included (uncommitted changes are not). After tests and the verifier pass in the worktree and you approve the diff, Claude runs `git merge --squash` so the task arrives staged for you to commit, then removes the worktree. Worktrees isolate files only: test databases, ports and containers are still shared. Add `.claude/worktrees/` to `.gitignore`.

grok is run through its bridge script from Bash with `--write`, because dispatching the `grok-build:grok-delegate` agent in auto mode can have its nested write denied.

## Status line

With `ogxo-statusline` set up, the status line shows this session's subagent count and how many generic dispatches ran without a model, read from the same log (`⇄ 5 subagents · 2 no-model`).

## Per-repository settings

Create `.claude/ogxo-route.md` in a repository to add risky paths (for example `contracts/`) or change the breadth threshold (default: more than 5 files, or more than one top-level package). The routing skill and the verifier read it.

## Limits

- Routing is advice to the model. The hooks warn and log; they do not enforce it.
- "Requested model" in stats is the `model` passed on a dispatch; when none is passed, the agent's pin or the session model applied and is not recorded.
- Only grok's exhausted-balance error (HTTP 402) is detected automatically. Codex quota errors and other grok failures are marked off by Claude when it sees them, or by you with `/ogxo-route:external off <name>`.

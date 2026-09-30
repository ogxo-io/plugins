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

All eight warn, log, alert, record, or set the routing marker; none rejects a tool call or answers a permission prompt.

- **anchor** (SessionStart): prints the routing summary. Prints nothing unless `CLAUDECODE=1`, so it stays quiet under Grok Build.
- **generic-warn** (PreToolUse `Agent|Task`): when Explore, general-purpose, or Plan is dispatched without a `model`, adds a note for Claude suggesting `haiku` or `sonnet`. The dispatch has already started on the session model; the note steers the next one.
- **quota-watch** (PostToolUse `Agent|Task|Bash`): when a grok run (the `grok-build:grok-delegate` agent, or a Bash call to `grok-bridge.mjs`) fails with HTTP 402 "usage balance exhausted", marks grok off for routing for 24 hours and adds a note for Claude. Rate limits (429) are ignored. A grok run you ask for by name still goes to grok.
- **permission-log** (PermissionRequest, and Notification `permission_prompt|agent_needs_input`): appends the time, session id, event, tool name, notification type, permission mode, whether it came from inside a subagent, and which subagent to `permissions.jsonl` in the plugin's data directory. No command or message text. It prints nothing, so it leaves the permission decision to Claude Code. The log shows where workers wait on prompts; whether these events fire for a background worker's prompt is not documented, and this log is how the team finds out.
- **prompt-alert** (Notification `permission_prompt|agent_needs_input`): off until you run `/ogxo-route:alerts on`. Then a desktop notification when Claude Code waits on you: on macOS through `terminal-notifier` if installed (`brew install terminal-notifier`; clicking it brings the app running Claude Code forward), otherwise, or when macOS has not allowed `terminal-notifier`'s notifications (System Settings → Notifications), `osascript` (clicking it opens Script Editor, which owns those notifications); on Linux through `notify-send`. With a push URL it also sends a POST of a fixed message to it (for example an ntfy topic). The push never includes the prompt's text. A prompt still waits until you answer it.
- **dispatch-log** (PostToolUse `Agent|Task`): appends the time, session id, agent type, requested model, whether it ran inside a subagent, and which subagent dispatched it to `dispatches.jsonl` in the plugin's data directory. No prompt text or paths.
- **advisor-count** (PreCompact, SessionEnd): counts the session's advisor calls and appends the time, session id, that count, and the number of assistant entries read to `advisor.jsonl` in the plugin's data directory. The advisor runs on the API side, so no tool hook sees it; this reads the session transcript and counts `server_tool_use` entries named `advisor`, once per id. The transcript format is Claude Code's own and undocumented, so a change to it shows up in stats as transcripts with no assistant entries recognised rather than as zero calls. Only the main session's transcript is read. A session killed before it ends or compacts logs nothing. No text or paths.
- **dash-event** (UserPromptSubmit, PreToolUse, PostToolUse, PostToolUseFailure, PermissionRequest, Notification `permission_prompt|agent_needs_input`, SubagentStart, SubagentStop, Stop, SessionEnd): records events for the live board, only for sessions where you turned the board on. It exits in bash, before running `jq`, when no board is on or when this session's own board is off, so a board open in another project doesn't slow this one down.

## Commands

- `/ogxo-route:external [on|off grok|codex [hours]]`: mark an external agent off for routing when its quota or login runs out (default 24 hours), back on, or show status (with the path of the state file it uses). A grok or codex run you ask for by name is not affected.
- `/ogxo-route:dashboard [on|off|status|hub|demo]`: open the live board for this session (default `on`), stop recording, show where it is, list every session's board, or open a replay of a made-up session to see what it looks like.
- `/ogxo-route:stats [days]`: dispatches per agent and requested model, and how many generic dispatches ran with no model, then the log's path; then permission requests and prompt notifications by mode and by main session or subagent; then advisor calls across ended sessions, and how many sessions that dispatched `implementer-risky` have no recorded advisor call (which can also mean the advisor tool was not enabled). Keeps 30 days.
- `/ogxo-route:alerts [on [https-push-url] | off | test]`: turn prompt alerts on or off, send a test alert, or show status.

## Parallel work

Before running several implementation tasks at once, the routing skill has Claude write a batch table (task, writer, files it may edit, off-limits files, mode, and anything created for the task outside the repository files, such as a build directory or test database, so it is removed afterwards).

- **Build outputs:** shared by default. Worker briefs keep the machine's and project's build cache settings (for example Cargo `target-dir`, `GOCACHE`, the pnpm store) instead of giving each task its own output, which rebuilds every dependency per task. A per-task output is used only when build flags differ or a watcher holds the build lock.

- **Shared tree (default):** every writer edits your checkout. Tasks run in parallel only on disjoint files, at most two writers at a time, each brief lists its allowed and off-limits files and tells the worker not to run git state-changing commands, and checks re-run on the combined tree before each task is committed. Tasks that touch migrations, schema, or generated files go to an isolated batch when a watcher or dev server runs on your checkout, because it can apply or generate from a half-finished file.
- **Isolated batch (opt-in, Claude asks first):** one git worktree per task under `.claude/worktrees/`, created from `HEAD` so unpushed commits are included (uncommitted changes are not). After tests and the verifier pass in the worktree and you approve the diff, Claude runs `git merge --squash` so the task arrives staged for you to commit, then removes the worktree. Claude checks free disk first and stops below 20 GiB. Removing a worktree also removes the build directories, test databases, and containers listed for it. Worktrees isolate files only: test databases, ports and containers are still shared. Add `.claude/worktrees/` to `.gitignore`.

grok is run through its bridge script from Bash with `--write`, because dispatching the `grok-build:grok-delegate` agent in auto mode can have its nested write denied.

Worker briefs also tell workers to skip a denied action and report it rather than stop, not to delete files they did not create, to run commands with directory flags or absolute paths instead of `cd <dir> && ...`, and to leave browser and E2E runs to the main session. A background worker's permission prompt waits in the main session until you answer it. Writes to external or production systems go one call at a time.

Review fix rounds use `ogxo-review:code-review-agent`'s re-review mode. After two rounds whose re-reviews report nothing above WARNING, the rest becomes follow-ups instead of another round.

## Live board

`/ogxo-route:dashboard` opens a local HTML page that follows the current session as it runs: the main session and every subagent it dispatches (model tier, description, its last tool calls, and the verifier's PASS/FAIL/RISKY), grok and codex bridge runs, the batch table, a timeline of tool calls per agent, how the tool calls split across model tiers, and a running log. Before the first parallel batch, Claude offers to open it.

- **One page per session, one hub for all of them.** Each session's board lives in the plugin's data directory under `dash/<session id>/`, so two projects running at once get separate pages. `/ogxo-route:dashboard hub` opens `dash/index.html`, which lists every board (repo, branch, working or idle, agents running, time since the last event) with a link to each, newest activity first; each board links back to it.
- **Local only.** The pages read `events.js` and `boards.js` from their own folders, so there is no server and no port. Press `t` to switch between the light and dark themes.
- **What it records.** Each event is built field by field in `hooks/dash-event.sh:60-107`: the event kind, the tool name, and a short summary, which is a file path relative to the project, the first two words of a shell command, a search pattern, a URL's host, a subagent's description, or, for a grok bridge run, up to 60 characters of its brief. The prompt, file contents, tool output, and a permission prompt's message are not among the fields it copies.
- **Waiting on you.** A permission request or an "agent needs input" notification marks the main session or the subagent that raised it: the board's header names it, its box shows `[ASK]`, and the hub card turns yellow, until that agent's next tool call or result. When Claude Code sends neither and no event has arrived for 90 seconds while work is still open, the board and the hub show a quiet warning instead.
- **Advisor calls.** The advisor runs on the API side, so no tool hook sees it. At the end of each turn and before each dispatch from the main session, the hook reads the part of the session transcript it has not read yet and records each advisor call once, by id, at the time the transcript gives it. The board marks them `<>` on the main lane and counts them, and flags an `implementer-risky` run with no advisor call seen. The transcript format is Claude Code's own and undocumented.
- **Stopping.** Recording stops at session end or with `/ogxo-route:dashboard off`. The files stay for replay; boards that are off and older than 7 days are pruned the next time a board is turned on.

## Status line

With `ogxo-statusline` set up, the status line shows this session's subagent count and how many generic dispatches ran without a model, read from the same log (`⇄ 5 subagents · 2 no-model`).

## Per-repository settings

Create `.claude/ogxo-route.md` in a repository to add risky paths (for example `contracts/`), change the breadth threshold (default: more than 5 files, or more than one top-level package), or change the free-disk threshold for worktrees (default 20 GiB). The routing skill and the verifier read it.

## Limits

- Routing is advice to the model. The hooks warn and log; they do not enforce it.
- "Requested model" in stats is the `model` passed on a dispatch; when none is passed, the agent's pin or the session model applied and is not recorded.
- The board shows what the hooks can see. grok and codex runs appear as their bridge calls, not their internal steps, and a subagent's model is the one Claude Code resolved for it, which is known once the dispatch returns.
- Only grok's exhausted-balance error (HTTP 402) is detected automatically. Codex quota errors and other grok failures are marked off by Claude when it sees them, or by you with `/ogxo-route:external off <name>`.

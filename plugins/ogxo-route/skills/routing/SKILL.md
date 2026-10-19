---
name: routing
description: Decide which agent, model, and effort handles each task so Claude usage windows last longer without losing code quality. Use before dispatching implementation, exploration, test, log, e2e, or review work to a subagent, and when choosing whether to do a task inline.
---

# Routing

The main session plans, classifies, and routes. Workers do scoped work.
Core-risk work and every mandatory review stay at Opus or above; contained
risk may run on Sonnet or grok and then gets the Opus review. This is an
instruction set; the hooks only warn and log.

Some steps send you to a reference file: `references/<name>.md` means
`${CLAUDE_PLUGIN_ROOT}/skills/routing/references/<name>.md` (if that path is
not filled in, the `references` folder next to this SKILL.md). Read it with
the Read tool at the point the step says, and again after a compaction
dropped it. Those files write ogxo-route's folder as `<plugin-root>` (here
`${CLAUDE_PLUGIN_ROOT}`) and its data folder as `<plugin-data>` (here
`${CLAUDE_PLUGIN_DATA}`).

## Step 0: repository overrides

If `.claude/ogxo-route.md` exists in the project, read it first. It may add
risky paths and change the breadth threshold or the free-disk threshold for
worktrees. Do not treat it as removing any trigger below.

## Step 1: do it inline when that is cheaper

- Answer from the conversation, or from one known command (`git log`, `rg`, `jq`), in the main session.
- The third search or read on the same question means you are exploring: hand the question to `ogxo-route:scout` with what you already know.
- A standard task small enough to finish in a few edits with no exploration (roughly one file) is done inline. The implement, test, and verify chain costs more than it saves below that size.

## Step 2: classify the task (before dispatch)

| Class | Rule |
|---|---|
| Standard | One scoped task from an approved plan, including mechanical changes. |
| Risky | Any trigger below. |
| Main session | Design, debugging with an unclear root cause, ambiguous requirements, anything that needs the user's judgement. Keep it in the main session. |

Risk triggers, any one is enough:
1. Security: changing authentication or authorization logic or policy (who may do what), crypto, secrets, input validation at a trust boundary. A new endpoint or query that applies an existing guard unchanged is not this trigger.
2. Data: destructive or rewriting migrations (drop, rename, type change, backfill, a new NOT NULL column without a default), deletes, and changes to existing data. An additive migration (a new table, index, or nullable or defaulted column) with tests is not this trigger.
3. Money or value: payments, billing, balances, smart contracts.
4. Concurrency or shared state: locks, races, cache invalidation, distributed state.
5. Public contracts: exported APIs, wire formats, CLI flags, config schemas, manifests.
6. Infrastructure or irreversible operations: CI, deploys, IaC, release tooling.
7. The touched code has no test coverage.
8. Unsure: classify up, never down.

Risk tiers. **Core risk** is trigger 1 (authentication or authorization
logic, crypto, secrets, trust-boundary validation), 2 (destructive or
rewriting migrations, deletes, changes to existing data), 3 (money), 4
(concurrency), 6 (infrastructure, irreversible operations), and 8 (unsure): a
mistake there is costly and tests may not show it, so the task runs on the
session model. **Contained risk** is trigger 5 (a public contract that stays
compatible: a new field, endpoint, or flag) and 7 (untested code): tests and
the risky-task review on Opus catch a mistake, so the task can run on a
cheaper model. Both tiers get that review. At list prices Sonnet 5.5 costs
half of Opus 5.5 in every token class, cache reads included, so moving a task
down halves its cost whatever its length.

Breadth threshold: more than 5 files, or more than one top-level package
(unless `.claude/ogxo-route.md` sets another value). Breadth is not a risk
trigger: it decides reviews (Step 4), never the implementer's tier.

Classify each task, not the ticket. When one part of a ticket hits a
trigger (the migration, the authorization guard, the money calculation),
split it out as a small risky task for `ogxo-route:implementer-risky` that
runs first, and give the rest (services, routes, UI, tests around it) to
the standard implementer as its own task. A long risky task is the most
expensive thing to route: every tool call re-reads the agent's whole
context at Opus prices.

A worked split of a mixed ticket (a public payload field, a migration, and a
UI picker) is in `references/classify-example.md`: read it the first time a
ticket mixes a trigger with standard work and the split is not obvious. A
risky brief names one trigger and one deliverable; one that lists several
triggers, or an API and its UI together, is two or more tasks. The parts
moved down still pass the verifier, which marks a diff RISKY when
a path matches `scripts/risky-paths.sh` (migration, auth, and similar path
segments), and a RISKY path gets the risky-task review.

## Step 3: route

**Opus rule:** pass `model: "opus"` only when the session model is below
Opus (Sonnet or Haiku). On an Opus or Fable session pass no `model`, so the
agent inherits the session model.

| Task | First choice, if installed and not marked off | Native |
|---|---|---|
| Explore or trace code | — | `ogxo-route:scout` |
| Tests, builds, linters | — | `ogxo-route:test-runner` |
| Bulk logs: pull and filter | — | `ogxo-route:log-extractor`, then `ogxo-specialists:log-analyst` |
| Small logs, interpretation | — | `ogxo-specialists:log-analyst` |
| E2E run and failure interpretation | — | `ogxo-route:e2e-runner` |
| Implement, standard | grok through its bridge (read `references/grok-bridge.md` first) or `codex:codex-rescue` | `ogxo-route:implementer` |
| Implement, contained risk | grok through its bridge (read `references/grok-bridge.md` first) or `codex:codex-rescue` | `ogxo-route:implementer-risky` with `model: "sonnet"` |
| Implement, core risk | — (native only) | `ogxo-route:implementer-risky` (Opus rule) |
| Per-task check | — | tests (`ogxo-route:test-runner`) and `ogxo-route:verifier` |
| Risky-task review | — | `ogxo-review:code-review-agent` (Opus rule) |
| Pre-PR review of the branch | — | `ogxo-review:code-review-agent` (Opus rule) |
| Explore, general-purpose, Plan | — | always pass `model`: `haiku` to list files, `sonnet` for judgement |

**grok:** run it through its bridge script from Bash, not the `grok-build:grok-delegate` agent: in auto mode the agent's nested write can be denied by the permission check. Before the first bridge call in a session, read `references/grok-bridge.md`: it gives the bridge path, the `CLAUDE_PLUGIN_DATA` setting every call needs, why `--write` is required, and how to watch, stop, and resume a run, and why you never type into one. The user can still ask for the agent or `/grok-build:delegate` by name.

`/codex:review` and `/grok-build:review` set `disable-model-invocation: true`, so only the user can run them. Before
a PR, suggest the user runs them as an extra pass if they have them; the
native review above is still required.

## Step 4: verify and escalate

1. Run the check: tests, then `ogxo-route:verifier` with the task text and the diff range.
2. `VERDICT: RISKY` on a path rule: the task becomes risky and gets the risky-task review.
3. `VERDICT: RISKY` on breadth only: no per-task review; the pre-PR review covers it.
4. `VERDICT: FAIL` or failing tests on a native worker: retry once one tier up (`implementer` → `implementer-risky`; a contained-risk task that ran on `implementer-risky` with sonnet → `implementer-risky` on the session model) with the failed attempt's RESULT and UNCERTAINTIES attached. A second failure comes back to the main session.
5. Failure on a routing-chosen external run: show the diff it left, restore the files it touched (`git restore <files>`), and re-dispatch natively with the failure attached: a standard task to `ogxo-route:implementer`, a contained-risk task to `ogxo-route:implementer-risky` on the session model.
6. A return that is unfinished with no blocker named is a continuation: dispatch a fresh worker at the same tier with the first one's RESULT in the brief. A `RESULT: PARTIAL` return names a handoff file: dispatch a fresh worker with the original brief and that path, not a follow-up message to the first worker.
7. The pre-PR review is the backstop for any per-task misclassification.
8. Review fix rounds: re-review a fix with the reviewer's re-review mode (the prior findings plus the range since the last review), not a fresh full review. After two fix rounds whose re-reviews report nothing above WARNING, stop looping: list the remaining items as follow-ups (the reviewer's Deferred section drafts them) and move on. When instead each round finds a new bypass or race of the kind the last fix closed, the design is the problem: after two such rounds stop patching, consult the advisor (Step 6), and brief the simplest structural design (a whitelist over a blacklist, one lock or claim over coordination).

## Step 5: external agents

- Before routing to grok or codex, check the session-start summary for "marked off" lines. Skip an agent marked off; this affects routing only.
- grok reporting an exhausted balance (HTTP 402) is marked off automatically by a hook, which adds a note saying so; follow it. Any other authentication or quota failure on a routing-chosen grok or codex run: tell the user, run `/ogxo-route:external off <grok|codex>`, and re-dispatch natively (Step 4.5).
- A grok or codex run the user asked for by name always goes through its bridge, even when marked off. If it fails, report the failure and point to `/grok-build:check` or `/codex:setup`. Do not substitute a Claude worker.
- When the quota is back: `/ogxo-route:external on <name>`.

## Running under Grok Build

If the host's tools are `spawn_subagent` and `run_terminal_command` rather
than `Agent` and `Bash`, this is Grok Build: read `references/grok-host.md`
before the first dispatch. Workers run on the session model there, no
session-start summary was shown, and the grok bridge and the advisor do not
apply.

## Step 6: advisor

Only when the `advisor` tool is available. Consult it:
- before choosing an approach on risky or one-way work,
- before declaring a risky task or a branch done,
- when stuck after an escalation,
- when review rounds keep opening new holes (Step 4.8).

Do not consult it for standard work. A teammate working on a Sonnet session
can enable an Opus advisor for risky work; keep that session at its default
effort, because the advisor is consulted less often at low effort.

## Step 7: hand-off format

- Pass paths, `file:line` ranges, and commit SHAs, not pasted file content.
- Map before dispatching an implementer into code this session has not read, and always before `ogxo-route:implementer-risky`: have `ogxo-route:scout` list the files, functions, and existing patterns the task touches (where the guard helpers, the closest similar endpoint, the test fixtures live), and put that map in the brief as `file:line` references. The worker starts from the map instead of searching, and exploration runs on the cheaper model.
- Give each worker a self-contained task: goal, files, acceptance checks. Paste a ticket's acceptance text verbatim, not paraphrased, and mark your own decisions as yours.
- Size each implementation task to about 60 tool calls: one coherent change in one area. A larger ticket is several tasks, run one after another, each brief carrying the previous task's RESULT and handoff path. Every call re-reads the worker's whole context, so cost grows faster than the number of calls, and a worker that explores for hours pays for that context on every call.
- Give each implementer a handoff path outside the repository (the session scratchpad directory when you have one, else `${TMPDIR:-/tmp}/ogxo-handoff/<task>.md`). It writes progress there when it stops at its call cap, and the next worker starts from that file and the map, with a small context of its own.
- Share context through the brief and the handoff file, not by forking or by continuing a worker with a follow-up message. A fork inherits the main context and re-reads it on every call, so use one only for a short task that needs the whole conversation. A worker's cache expires after 5 minutes idle, so a follow-up to a worker that has finished rewrites its whole context.
- Dispatch independent read-only work (scout, test-runner, log-extractor) in parallel, in one message. Parallel implementation follows Step 8.
- Full suites, e2e runs, and builds that take more than a few minutes go to `ogxo-route:test-runner` or `ogxo-route:e2e-runner`, with `run_in_background: true` when other work can go on meanwhile. They start the command with `${CLAUDE_PLUGIN_ROOT}/scripts/longrun.sh` and wait in calls of under 2 minutes, so the wait costs a small context kept warm, not a worker's large one rewritten. An implementer never waits on one: it runs the tests it touched and names the full run for you to dispatch. Run e2e suites one at a time unless they use separate databases and ports.
- Writes to external or production systems (MCP servers, issue trackers, APIs) go one call per message, never in a parallel batch. On a rate-limit error (HTTP 429 or the service's equivalent), wait the `retry_after` it gives, or back off, before resending.
- Every ogxo-route worker ends with `RESULT`, `CHECKS-RUN`, `UNCERTAINTIES`; read them before accepting the work.

Every implementation brief also says:
- You are the implementer: do the task yourself even if your own global instructions route work elsewhere, and make no writes to MCP servers, trackers, or other external systems.
- If an action is denied, skip it, record it under UNCERTAINTIES, and continue with the rest of the task.
- Start from the map in this brief; search only for what it does not cover.
- Stop at about 60 tool calls with the task unfinished and write progress to the handoff file at <path>; end with `RESULT: PARTIAL <path>: <what remains>`.
- Keep any single wait (a long command, `sleep`, an `until` loop) under 4 minutes and check again in a new call; run the tests your change touches, and name the full-suite run under UNCERTAINTIES.
- Do not delete or clean up files you did not create; report them instead.
- Run commands from the target directory with the tool's own directory flag where it has one (for example `git -C`, `pnpm --dir`, `uv --directory`, `go -C`, `cargo --manifest-path`) or with absolute paths, not `cd <dir> && ...`: a `cd` in a compound command can trigger a permission prompt.
- Do not launch browsers or run E2E suites; write or update the specs and say which to run. The main session runs them, or dispatches `ogxo-route:e2e-runner`.
- The project's own `CLAUDE.md` or build and test docs take precedence over this brief on how to build, test, and migrate.

A long main session costs more with every message, because each one re-reads all of it. At a boundary (a ticket merged, a batch landed, before the user steps away) with a long context, suggest `/ogxo-route:handoff` and then, instead of carrying on, `/clear` when the next task is unrelated (it costs nothing) or `/compact` when the next task builds on this one (compacting sends the whole conversation once more, as one large request); `/ogxo-route:handoff resume` picks it up. To drop a dead end without losing the rest, suggest `/rewind` to the turn before it: that returns to a prefix that is already cached.

A background worker's permission prompt waits in the main session until someone answers it, and the worker makes no progress meanwhile. Claude Code has no documented stalled-subagent signal, so when a background worker has been quiet for much longer than its task should take, check the session for a pending prompt.

## Step 8: parallel batches

Before dispatching more than one implementation task at a time, read
`references/parallel-batches.md` and write its **Batch table** in the
conversation (task, writer, files it may edit, off-limits files, mode, and
anything created outside the repository). The rules it sets out: a
parallel-work or worktree rule in the project's `CLAUDE.md`, `AGENTS.md`, or
`.claude/ogxo-route.md` wins over the defaults; the shared tree is the
default, with at most two concurrent writers, a hard cap; isolated per-task
worktrees are opt-in, so ask first; build outputs and dependency caches stay
shared; tasks that touch migrations, schema, or generated artefacts run
isolated while a watcher runs on the checkout. Before the first batch in a
session, offer `/ogxo-route:dashboard` once.

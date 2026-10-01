---
name: routing
description: Decide which agent, model, and effort handles each task so Claude usage windows last longer without losing code quality. Use before dispatching implementation, exploration, test, log, e2e, or review work to a subagent, and when choosing whether to do a task inline.
---

# Routing

The main session plans, classifies, and routes. Workers do scoped work.
Risky work and every mandatory review stay at Opus or above. This is an
instruction set; the hooks only warn and log.

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

Breadth threshold: more than 5 files, or more than one top-level package
(unless `.claude/ogxo-route.md` sets another value). Breadth is not a risk
trigger: it decides reviews (Step 4), never the implementer's tier.

Classify each task, not the ticket. When one part of a ticket hits a
trigger (the migration, the authorization guard, the money calculation),
split it out as a small risky task for `ogxo-route:implementer-risky` that
runs first, and give the rest (services, routes, UI, tests around it) to
the standard implementer as its own task. A long risky task is the most
expensive thing to route: every tool call re-reads the agent's whole
context at Opus prices. The parts moved down still pass the verifier, which marks a diff RISKY when
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
| Implement, standard | grok through its bridge (see below) or `codex:codex-rescue` | `ogxo-route:implementer` |
| Implement, risky | — (native only) | `ogxo-route:implementer-risky` (Opus rule) |
| Per-task check | — | tests (`ogxo-route:test-runner`) and `ogxo-route:verifier` |
| Risky-task review | — | `ogxo-review:code-review-agent` (Opus rule) |
| Pre-PR review of the branch | — | `ogxo-review:code-review-agent` (Opus rule) |
| Explore, general-purpose, Plan | — | always pass `model`: `haiku` to list files, `sonnet` for judgement |

To run grok, call its bridge from Bash rather than dispatching the `grok-build:grok-delegate` agent: in auto mode the agent's nested write can be denied by the permission check. Find the script with `ls -d "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/plugins/cache/*/grok-build/*/scripts/grok-bridge.mjs | tail -1`, then run `node <path>/grok-bridge.mjs run --background --write --fresh "<brief>"` from the directory the task works in (`--write` is required; without it grok runs read-only and leaves only a patch). Follow up with `show <run-id>`, and `run --background --write --resume-last` for a fix round. The user can still ask for the agent or `/grok-build:delegate` by name.

`/codex:review` and `/grok-build:review` set `disable-model-invocation: true`, so only the user can run them. Before
a PR, suggest the user runs them as an extra pass if they have them; the
native review above is still required.

## Step 4: verify and escalate

1. Run the check: tests, then `ogxo-route:verifier` with the task text and the diff range.
2. `VERDICT: RISKY` on a path rule: the task becomes risky and gets the risky-task review.
3. `VERDICT: RISKY` on breadth only: no per-task review; the pre-PR review covers it.
4. `VERDICT: FAIL` or failing tests on a native worker: retry once one tier up (`implementer` → `implementer-risky`) with the failed attempt's RESULT and UNCERTAINTIES attached. A second failure comes back to the main session.
5. Failure on a routing-chosen external run: show the diff it left, restore the files it touched (`git restore <files>`), and re-dispatch to `ogxo-route:implementer` at the same class with the failure attached.
6. A return that is unfinished with no blocker named is a continuation: resume at the same tier.
7. The pre-PR review is the backstop for any per-task misclassification.
8. Review fix rounds: re-review a fix with the reviewer's re-review mode (the prior findings plus the range since the last review), not a fresh full review. After two fix rounds whose re-reviews report nothing above WARNING, stop looping: list the remaining items as follow-ups (the reviewer's Deferred section drafts them) and move on.

## Step 5: external agents

- Before routing to grok or codex, check the session-start summary for "marked off" lines. Skip an agent marked off; this affects routing only.
- grok reporting an exhausted balance (HTTP 402) is marked off automatically by a hook, which adds a note saying so; follow it. Any other authentication or quota failure on a routing-chosen grok or codex run: tell the user, run `/ogxo-route:external off <grok|codex>`, and re-dispatch natively (Step 4.5).
- A grok or codex run the user asked for by name always goes through its bridge, even when marked off. If it fails, report the failure and point to `/grok-build:check` or `/codex:setup`. Do not substitute a Claude worker.
- When the quota is back: `/ogxo-route:external on <name>`.

## Step 6: advisor

Only when the `advisor` tool is available. Consult it:
- before choosing an approach on risky or one-way work,
- before declaring a risky task or a branch done,
- when stuck after an escalation.

Do not consult it for standard work. A teammate working on a Sonnet session
can enable an Opus advisor for risky work; keep that session at its default
effort, because the advisor is consulted less often at low effort.

## Step 7: hand-off format

- Pass paths, `file:line` ranges, and commit SHAs, not pasted file content.
- Map before dispatching an implementer into code this session has not read, and always before `ogxo-route:implementer-risky`: have `ogxo-route:scout` list the files, functions, and existing patterns the task touches (where the guard helpers, the closest similar endpoint, the test fixtures live), and put that map in the brief as `file:line` references. The worker starts from the map instead of searching, and exploration runs on the cheaper model.
- Give each worker a self-contained task: goal, files, acceptance checks.
- Dispatch independent read-only work (scout, test-runner, log-extractor) in parallel, in one message. Parallel implementation follows Step 8.
- Writes to external or production systems (MCP servers, issue trackers, APIs) go one call per message, never in a parallel batch. On a rate-limit error (HTTP 429 or the service's equivalent), wait the `retry_after` it gives, or back off, before resending.
- Every ogxo-route worker ends with `RESULT`, `CHECKS-RUN`, `UNCERTAINTIES`; read them before accepting the work.

Every implementation brief also says:
- If an action is denied, skip it, record it under UNCERTAINTIES, and continue with the rest of the task.
- Start from the map in this brief; search only for what it does not cover.
- Do not delete or clean up files you did not create; report them instead.
- Run commands from the target directory with the tool's own directory flag where it has one (for example `git -C`, `pnpm --dir`, `uv --directory`, `go -C`, `cargo --manifest-path`) or with absolute paths, not `cd <dir> && ...`: a `cd` in a compound command can trigger a permission prompt.
- Do not launch browsers or run E2E suites; write or update the specs and say which to run. The main session runs them, or dispatches `ogxo-route:e2e-runner`.
- The project's own `CLAUDE.md` or build and test docs take precedence over this brief on how to build, test, and migrate.

A background worker's permission prompt waits in the main session until someone answers it, and the worker makes no progress meanwhile. Claude Code has no documented stalled-subagent signal, so when a background worker has been quiet for much longer than its task should take, check the session for a pending prompt.

## Step 8: parallel batches

Before dispatching more than one implementation task at a time, write a
**Batch table** in the conversation, one row per task: task, writer (grok,
codex, implementer), files it may edit, files that are off-limits because
another task owns them, mode (shared or isolated), and anything created for
it outside the repository files (a build directory, test database,
container, or port), so it can be removed when the task is done.

Build outputs and dependency caches are shared by default. Honour the
machine's and project's existing settings (for example Cargo `target-dir`,
`GOCACHE`, the pnpm store, the uv cache, `GRADLE_USER_HOME`) and do not
override them in briefs. Most toolchains lock or queue on a shared cache,
and that wait costs far less than rebuilding every dependency per task,
which multiplies build time and disk use. Give a task its own build output
only when it builds with different flags or features, or when a
long-running process (a watcher or dev server) holds the shared build lock;
list that output in the Batch table. The project's own `CLAUDE.md` or build
docs take precedence.

Tasks that append to the same file (a test file, changelog, route or
registry table, fixture list) always conflict when merged. Tell each worker
to add its entries in one contiguous block headed by the task id, not
interleaved with others.

**Live board.** Before the first batch in a session, offer the user
`/ogxo-route:dashboard` once: a local HTML page, updated by hooks, showing
this session's agents, their tool calls, and the batch. When the board is
on, record the Batch table on it and use each row's task name in that
task's dispatch description, so the board can link rows to agents:

```bash
CLAUDE_PLUGIN_DATA="${CLAUDE_PLUGIN_DATA}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/dash.sh" batch <<'JSON'
[{"task": "<task>", "writer": "<grok|codex|implementer>", "files": ["<path>"], "mode": "shared"}]
JSON
```

For an isolated task, set `"mode": "isolated"` and add `"worktree": ".claude/worktrees/<task>"`.

When the board is off, the script prints a note and writes nothing.

### Shared tree (default)

All writers edit the user's checkout. This is cheap and needs no setup.

- Run tasks in parallel only when their file sets do not overlap. A task that shares a file with a running task waits for it.
- At most two concurrent writers. grok's run state also contends beyond two runs.
- Watchers, hot reloaders, and dev servers that compile, apply, or generate from the working tree act on half-finished work: they can apply a draft migration (sqlx, Django, Prisma, goose, Alembic), run codegen or seeds, sync a schema, or rebuild bundles. On a shared database the damage outlives the task. Run tasks that touch migrations, schema, or generated artefacts in an isolated batch. Otherwise, before trusting E2E or integration results, check what was actually applied (the migration version table or checksums, with the project's own command).
- Every worker brief lists the files it may edit and the off-limits files, says not to run git add, commit, stash, checkout, reset, or restore, and says to leave changes it did not make alone and report them.
- A worker's own tests see the other runs' unfinished edits. Before committing a task, re-run typecheck, unit tests, and the relevant e2e specs on the combined tree.
- Commit each task by explicit path (`git add -- <its files>`), and only when the user asks. If two tasks touched the same file, split the hunks so each commit carries only its task.

### Isolated batch (opt-in)

One git worktree per task, merged back one at a time. Suggest it when the
user is editing the main checkout while the batch runs, when more than two
writers should run at once, when tasks that overlap in files must still run
in parallel, when a task touches migrations, schema, or generated artefacts
while a watcher runs on the main checkout, or when the user wants the main
tree untouched until a task is done. Ask before using it.

1. Check free disk first: `df -Pk .`. Below 20 GiB free (20971520 in its Available column), stop and tell the user instead of creating the worktree (`.claude/ogxo-route.md` can set another threshold). One cold dependency build of a large project can take about 10 GiB; 20 GiB leaves room for one more build and test artefacts.
2. Create the worktree from the current commit, so unpushed commits are included:
   `git worktree add .claude/worktrees/<task> -b task/<task> HEAD`.
   Uncommitted changes in the main checkout are not carried over; if the task depends on them, say so and stay in the shared tree. Keep worktrees under `.claude/worktrees/`, inside the project, and put that directory in `.gitignore`.
3. Set up the worktree: dependencies (install, or symlink `node_modules`), and gitignored files the build needs (a `.worktreeinclude` file copies them for worktrees Claude Code creates; copy them yourself for this one). Keep the shared build cache (above). Worktrees isolate files only: test databases, ports, and containers are still shared, so keep per-task test databases and distinct ports, and list them in the Batch table.
4. Point the writer at it: grok, from the worktree as the working directory (a plain `cd <worktree>` as its own command, then `node <path>/grok-bridge.mjs run --background --write --fresh ...`); codex `codex exec -C <worktree> ...` or `codex:codex-rescue` with the path in its prompt; `ogxo-route:implementer` with the absolute worktree path in its brief and the instruction to edit only under it.
5. Before a fix round in an existing worktree, run `git -C <worktree> status --porcelain` and stop on any file outside the task's scope. If the main branch has since changed files the task touches, recreate the worktree from the current `HEAD` and apply the task's diff as a patch (`git diff <base>..task/<task> > <patch>`, then `git -C <new-worktree> apply --3way <patch>`) rather than rebasing a long way.
6. When the task is done: run tests and `ogxo-route:verifier` inside the worktree, commit the task on its throwaway branch (`git -C <worktree> add -A && git -C <worktree> commit -m "<task>"`), show the user `git diff HEAD...task/<task>`, and only after the user approves run `git merge --squash task/<task>` in the main checkout. That stages the task for the user to review and commit. `git merge --squash` suits a task branch with several commits; `git cherry-pick -n <sha>` brings over a single commit the same way. Merge tasks one at a time and re-run the combined-tree checks after each.
7. Clean up: `git worktree remove .claude/worktrees/<task>` and `git branch -D task/<task>`. Removing the worktree deletes its directory, ignored files included, but nothing created outside it: also remove every build directory, test database, and container the Batch table lists for the task.

Conflicts do not go away in an isolated batch; they move to merge time. A
task that overlaps with one already merged is rebased onto the main branch
(`git -C <worktree> rebase <main-branch>`) and re-tested before its merge.

For a conflict in a file several tasks append to, keep one side whole and
re-add the other: take the main branch's file and append the task's block,
or take the task's file and re-apply the main branch's changes since the
worktree's base. Then check that no entry was dropped or duplicated by
comparing sorted test names before and after, extracted with the project's
test declaration pattern (for example `#[test]` then `fn name`, `it(`/`test(`,
`def test_`, `func Test`); `sort | uniq -d` shows duplicates, `comm -3`
shows what is missing.

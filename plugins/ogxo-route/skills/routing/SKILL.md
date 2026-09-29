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
risky paths and change the breadth threshold. Do not treat it as removing any
trigger below.

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
1. Security: authentication or authorization, crypto, secrets, input validation at a trust boundary, permissions.
2. Data: migrations, schema changes, deletes, backfills.
3. Money or value: payments, billing, balances, smart contracts.
4. Concurrency or shared state: locks, races, cache invalidation, distributed state.
5. Public contracts: exported APIs, wire formats, CLI flags, config schemas, manifests.
6. Infrastructure or irreversible operations: CI, deploys, IaC, release tooling.
7. The touched code has no test coverage.
8. Unsure: classify up, never down.

Breadth threshold: more than 5 files, or more than one top-level package
(unless `.claude/ogxo-route.md` sets another value).

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
- Give each worker a self-contained task: goal, files, acceptance checks.
- Dispatch independent read-only work (scout, test-runner, log-extractor) in parallel, in one message. Parallel implementation follows Step 8.
- Every ogxo-route worker ends with `RESULT`, `CHECKS-RUN`, `UNCERTAINTIES`; read them before accepting the work.

## Step 8: parallel batches

Before dispatching more than one implementation task at a time, write a
**Batch table** in the conversation, one row per task: task, writer (grok,
codex, implementer), files it may edit, files that are off-limits because
another task owns them, and mode (shared or isolated).

### Shared tree (default)

All writers edit the user's checkout. This is cheap and needs no setup.

- Run tasks in parallel only when their file sets do not overlap. A task that shares a file with a running task waits for it.
- At most two concurrent writers. grok's run state also contends beyond two runs.
- Give each run its own build output where builds collide, for example `CARGO_TARGET_DIR=target/<task>`.
- Every worker brief lists the files it may edit and the off-limits files, says not to run git add, commit, stash, checkout, reset, or restore, and says to leave changes it did not make alone and report them.
- A worker's own tests see the other runs' unfinished edits. Before committing a task, re-run typecheck, unit tests, and the relevant e2e specs on the combined tree.
- Commit each task by explicit path (`git add -- <its files>`), and only when the user asks. If two tasks touched the same file, split the hunks so each commit carries only its task.

### Isolated batch (opt-in)

One git worktree per task, merged back one at a time. Suggest it when the
user is editing the main checkout while the batch runs, when more than two
writers should run at once, when tasks that overlap in files must still run
in parallel, or when the user wants the main tree untouched until a task is
done. Ask before using it.

1. Create the worktree from the current commit, so unpushed commits are included:
   `git worktree add .claude/worktrees/<task> -b task/<task> HEAD`.
   Uncommitted changes in the main checkout are not carried over; if the task depends on them, say so and stay in the shared tree. `.claude/worktrees/` should be in `.gitignore`.
2. Set up the worktree: dependencies (install, or symlink `node_modules`), gitignored files the build needs (a `.worktreeinclude` file copies them for worktrees Claude Code creates; copy them yourself for this one), and a build output directory. Worktrees isolate files only: test databases, ports, and containers are still shared, so keep per-task test databases and distinct ports.
3. Point the writer at it: grok `cd <worktree> && node <path>/grok-bridge.mjs run --background --write --fresh ...`; codex `codex exec -C <worktree> ...` or `codex:codex-rescue` with the path in its prompt; `ogxo-route:implementer` with the absolute worktree path in its brief and the instruction to edit only under it.
4. When the task is done: run tests and `ogxo-route:verifier` inside the worktree, commit the task on its throwaway branch (`git -C <worktree> add -A && git -C <worktree> commit -m "<task>"`), show the user `git diff HEAD...task/<task>`, and only after the user approves run `git merge --squash task/<task>` in the main checkout. That stages the task for the user to review and commit. Merge tasks one at a time and re-run the combined-tree checks after each.
5. Remove the worktree and its branch: `git worktree remove .claude/worktrees/<task>` and `git branch -D task/<task>`.

Conflicts do not go away in an isolated batch; they move to merge time. A
task that overlaps with one already merged is rebased onto the main branch
(`git -C <worktree> rebase <main-branch>`) and re-tested before its merge.

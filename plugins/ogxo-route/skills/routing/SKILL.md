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
| Implement, standard | `grok-build:grok-delegate` or `codex:codex-rescue` | `ogxo-route:implementer` |
| Implement, risky | — (native only) | `ogxo-route:implementer-risky` (Opus rule) |
| Per-task check | — | tests (`ogxo-route:test-runner`) and `ogxo-route:verifier` |
| Risky-task review | — | `ogxo-review:code-review-agent` (Opus rule) |
| Pre-PR review of the branch | — | `ogxo-review:code-review-agent` (Opus rule) |
| Explore, general-purpose, Plan | — | always pass `model`: `haiku` to list files, `sonnet` for judgement |

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
- Dispatch independent tasks in parallel, in one message.
- Every ogxo-route worker ends with `RESULT`, `CHECKS-RUN`, `UNCERTAINTIES`; read them before accepting the work.

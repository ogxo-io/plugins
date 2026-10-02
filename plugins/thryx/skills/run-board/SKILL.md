---
name: run-board
description: Use when the user asks to run, work through, burn down, or drain a ThryX board or backlog - fetch a project's open Todo tickets (for one assignee or all), plan them into waves, work them in parallel with subagents, keep each ticket's status current, and stop at a checkpoint so a long run can continue in a fresh session ("run the board", "work all my Todo tickets in KEY", "continue the board"). Not for working one named ticket (the thryx skill) or for planning a cycle (product-management).
---

# Running a ThryX board

This skill turns a project's Todo tickets into finished work without one
session carrying all of it. The board is the state: a ticket's status says
what is done, running, or waiting, so a session can stop at any wave
boundary and a new one can pick up from the board. Read the thryx skill
first for how the tools behave (workspace, starting a ticket, batching, the
one-write-per-message rule); this skill adds the loop around them. When
ogxo-route is installed, its routing skill decides who does each task; it is
named where it applies below.

## 1. Take the request apart

- **Project:** the key in the request, else a `ThryX project: KEY` line in
  `CLAUDE.md` or `AGENTS.md`, else the key in the branch name. Ask only when
  none of those names one.
- **Whose tickets:** "mine" or no one named means the token owner (`whoami`
  gives the email); a name or email means that person; "all" means anyone,
  including unassigned.
- **How many:** at most 8 tickets per run unless the user names a number.
  The cap is what keeps the main session short; a larger board takes
  several runs.
- **Commits:** by default the work stays uncommitted in the working tree or
  the ticket's worktree and nothing is pushed. Ask in the plan whether to
  commit per ticket (one commit each, no push, no pull request unless asked).
- **"Continue the board"** means a previous run stopped at a checkpoint:
  do step 7 first, then the rest.

## 2. Read the board cheaply

1. `list_statuses` for the project, for the names you will write. Statuses
   carry a `category`: Todo-like states are `unstarted` (named Ready or
   Backlog, depending on the project), in progress is `started`, and Triage
   is its own `triage` category. Don't guess names.
2. `list_issues` with `project_key`, `assignee_email` when a person was
   asked for, and `limit: 200`. It has no status filter, so keep the rows
   whose `status_category` is `unstarted` yourself. Rows in `triage` have not
   been accepted yet: leave them out unless the user named that status. A row
   carries `key`, `title`, `issue_type`, `priority`, `status_name`, the
   assignee's name (not the email), `estimate`, `parent_title`, and `blocked`
   (`by` lists blocking tickets, `reason` a free-text reason), but not the
   description. The result's `truncated` says it was cut short; say so in the
   plan.
3. Drop what a session should not pick up, and list each drop with its
   reason in the plan: epics (their children are the work: read them with
   `parent_issue_key`, and run an epic's children when the epic is what was
   named), tickets whose `blocked.by` or `blocked.reason` is set,
   and `decision` and `research` tickets (they need the user's judgement).
4. For the candidates you will actually run, `get_issue` for the
   description, labels, and sprint. A ticket with no description or no way
   to tell when it is done is left out and offered for refinement. Do this
   for the first wave only, not the whole board.

## 3. Plan once, then ask once

Order by priority (urgent first), then tickets in the running sprint, then
the rest. Group into waves of at most two writers on disjoint files plus any
read-only work, the shape ogxo-route's Step 8 describes. A ticket that
touches the same files as a running one goes to a later wave.

Show one table: key, title, priority, class (standard, contained risk, core
risk, from the routing skill), wave, and the ticket it waits for. Add the
`estimate` column when the project uses estimates. Then say
in specifics what the run will write: statuses moved, assignees set,
comments added, and commits if asked. Name the holder of every ticket that
someone other than the token owner holds (they appear with "all", or when
another person's tickets were asked for): those get a status move only and
keep their assignee. The user answers once for the whole
run; don't ask again per ticket. Stop to ask only for a decision the plan
did not cover.

## 4. Claim a wave

One `update_issues` call moves the wave's tickets to the in-progress status
and sets `assignee_email` on those with no assignee. A ticket someone else
holds moves only when the plan listed it with its holder and the user
approved: its status changes and its assignee stays. The claim is the status
and the assignee; the branch or worktree name carries the key (for example
`THRY-12-short-title`), which is how a later session finds the work.

## 5. Work the wave

- **With ogxo-route:** follow its routing skill: scout map first, classify
  each task not the ticket, standard work to `ogxo-route:implementer`,
  the risky part of a ticket to `implementer-risky` (at the tier the
  routing skill gives it), about 60 tool calls per worker with a
  handoff file when one stops early, tests through `test-runner` (long suites
  and e2e in the background), `verifier` on each diff, the risky-task review
  on risky ones.
- **Without it:** one subagent per task with a self-contained brief (goal,
  files, acceptance checks, a rule not to commit), `model: sonnet` for
  implementation and `haiku` for lookups, two writers at most, and the
  tests re-run on the combined tree before a ticket counts as done.
- **Briefs** come from the ticket's description and acceptance checks; the
  workers have no ThryX tools, so put what they need in the brief. Pass
  paths and `file:line` references, not pasted code.
- **Keep the main session small.** Keep one run table in the conversation
  (key, state, branch, result in a line) and print only what changed after
  each worker returns. Never paste a worker's diff or log into the main
  session; read the `RESULT` line and the verifier's verdict.
- **Refill.** When a worker returns and a writer slot is free, claim and
  start the next ready ticket (one `update_issues` call for everything that
  became ready at once). Stop starting tickets at the cap from step 1.

## 6. Record each ticket as it finishes

- **Verified and left for review:** move it to the project's review status
  (the `started` status whose name says review) when there is one; otherwise
  leave it in progress. Add one comment: branch or commit, what changed, the
  checks run, anything left open. Comments are separate calls, one per
  message.
- **Failed or stuck:** leave it in progress, comment what blocked it and
  what was tried, and say so in the run table. A ticket that waits on
  something that is not another ticket gets a `blocked_reason` through
  `update_issues`.
- **Never** move a ticket to a `completed` or `canceled` status from here:
  done means merged and shipped, which the user decides. Don't create
  tickets silently either: work found on the way is listed in the summary,
  and the user decides which become tickets (see "Search before you
  create" in the thryx skill).
- Status changes for tickets that finish in the same wave go in one
  `update_issues` call.

## 7. Checkpoint, or continue

Stop starting new tickets when: the cap is reached; the user says the
status line shows the context getting long (300k tokens is yellow); a
rate-limit error comes back (wait the `retry_after`); a ticket needs the
user's decision; or the same check fails twice. Let the running wave
finish, record it (step 6), then print the run table as the summary and the
tickets still waiting, and tell the user to compact or start a fresh session
and say "continue the board". The board holds the ticket state; when ogxo-route is
installed, `/ogxo-route:handoff` can also save decisions and context that are
not on any ticket.

**Continue:** list the person's tickets in the in-progress status for the
project. For each one, look for local traces: a branch or worktree whose
name has the key, and handoff files from ogxo-route. With a diff or a
commit, go straight to verification and step 6. With a handoff file,
dispatch a fresh worker from it. With a branch but no diff, restart the
task. With no trace at all, the ticket is probably in someone's other
session or work done by hand: ask, don't touch it. Then go on from step 2
for what is still Todo.

## Throughout

Do not reassign a ticket another person holds, move a ticket to a finished
status, push, open pull requests, or send write calls in parallel. Write to
ThryX only what the plan listed. The irreversible-call contract in the thryx
skill applies unchanged.

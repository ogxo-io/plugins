# Following up

Following up means reading what changed, finding what is stuck, and
getting it written back where people will see it. A summary left only in
chat doesn't count. Every routine below ends with proposed write-backs,
and once the person answers, says what it wrote and where.

## Signals to raise every time

Lead with these whenever you see them. `project_report` finds six of
them for you in `signals`: each entry has a `kind`, a one-line
`meaning`, the full `count`, and up to 20 ticket keys or titles in
`items`. An empty list means nothing is flagged. Name the items and the
full count when a signal needs action.

| Signal | `kind` in `signals` |
| --- | --- |
| A ticket whose blockers are all done: it is free, so say so | `settled_blockers` |
| A ticket in progress or in review with no one assigned | `unassigned_started` |
| A ticket inside the live cycle still in Backlog or Triage | `backlog_in_active_cycle` |
| A gap between one scheduled cycle's end and the next one's start | `cycle_gap` |
| A milestone whose open tickets sit in no cycle ending by its date | `milestone_work_outside_target_cycle` |
| A deliverable or milestone at 100% whose status is still open | `completed_progress_open_status` |

The report doesn't find these, so check them yourself:

- a ticket someone has held in progress with no activity for 3 working
  days, or the project's own threshold if it states one;
- a blocked ticket (`list_relations`, or `blocked_reason`) whose blocker
  isn't moving;
- an urgent or high-priority ticket with no one assigned;
- a cycle whose remaining work is more than its remaining time can hold;
- a milestone that will miss its date at the current pace;
- work in the code with no ticket, or a ticket marked done with no merged
  pull request;
- a decision everyone is waiting on, with no `decision` ticket and no
  owner.

## Standup

1. `list_activity` for the project shows what actually moved (not
   updated dates). `project_brief` shows the running cycle.
2. From the repo, list pull requests merged or opened since the previous
   working day, and match them to tickets.
3. Report three things: what moved, what is stuck and why, and what
   needs a decision today.
4. Write back: offer a comment on each stuck ticket asking the specific
   question that would unstick it.

## Weekly review

1. Use `project_report` with `days: 14` for how the last stretch went.
   It already carries the `signals` above, `stale_issues`,
   `unassigned_open`, and the state and priority mix, so start from
   those. The server's `project_status` prompt walks the same report. Use `list_cycle_issues` for
   the current cycle. Read the whole backlog with `list_issues` only
   when the report points at something you need to see ticket by
   ticket, because it is the most expensive read here.
2. Go through the triage queue with the server's `triage_ticket`
   prompt, and propose a decision for each ticket.
3. Check the board (`references/client-board.md`) and the documents: is
   the project description still true, and is there a PRD whose scope
   has drifted from its tickets?
4. Propose any changes to priority or assignee, with what slips as a
   result. Write nothing until the person answers.
5. Propose the write-backs: the project `health` with a one-line
   reason, and a refreshed "where it stands" in the description when it
   has changed.

## After a release

1. Compare the release tag or CHANGELOG with the tracker. Look for
   tickets marked done that aren't in the release, and changes in the
   release that no ticket covers.
2. Propose the updates for the macro items that shipped: status and
   the client's copy (`references/client-board.md`, including holding
   back security fixes). Propose marking a milestone completed when its
   outcome shipped.
3. Propose a refreshed "where it stands" in the project description,
   and the release entry in the overview if the project keeps a history
   there.
4. Where the project keeps a runbook for releases, follow it and say
   which one you followed.

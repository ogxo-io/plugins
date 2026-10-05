# Replanning the cycles

A replan takes every open ticket in a project (Triage, Backlog, Ready,
and what the planned cycles already hold) and proposes, in one message,
where each one goes: into which cycle, back to the backlog, merged into
another, or closed, and whether the calendar needs more cycles or fewer.
`cycle.md` covers one cycle's goal, selection, and description; this
reference is the pass across all of them, and it uses cycle.md's rules
rather than restating them.

The running cycle is not replanned. Report its pace, and if something
should come in or go out, propose it as a separate swap ("adding means
removing" in cycle.md). A replan that reshuffles live work every week is
churn, not planning.

The project's own written planning rules win over this reference. When
its description or a decisions document says how many cycles exist,
how long they run, or what a priority means, follow that and cite where
it says so.

## 1. Read everything first

Make all of these calls, in this order, before proposing anything. Each
one answers a question the plan can't be made without.

1. `list_statuses`: the names, and which are `triage` and `unstarted`.
   `list_issues` has no status filter, so this is how you split Triage
   from Backlog and Ready.
2. `project_brief`: the running cycle (or that none is running), the
   next one, and the pace.
3. `project_report` with `days: 30`: `velocity` rows,
   `completed_by_day_14d` and `created_by_day_14d`, `signals`, `epics`
   (done and todo counts per epic), `stale_issues`, and
   `load_by_assignee`.
4. `get_timeline`: promise dates and their open criteria. Without it,
   nothing in the plan can be checked against a date.
5. `get_workload`: open tickets per person.
6. `list_cycles`: every cycle with its dates, status, and `time_used`.
7. `list_cycle_issues` for each planned cycle. `list_issues` doesn't
   say which cycle a ticket is in, so this is the only way to see what
   the planned cycles hold.
8. `list_issues` with `backlog_only: true` and `limit: 200`. It returns
   Triage tickets as well as Backlog and Ready, everything open that
   isn't in a planned or active cycle. When `truncated` is true, read
   again by `priority` or by `parent_issue_key` until nothing is cut.

Each ticket carries `blocked.by` with a `settled` flag per blocker and a
`blocked.reason` for waits that aren't tickets, so blockers don't need a
`list_relations` call per ticket.

## 2. Audit the calendar

Sort the cycles by `start_date`, not by number, and report:

- cycles whose dates overlap;
- a cycle marked completed whose end date hasn't arrived yet;
- gaps: a planned cycle that doesn't start the day after the previous
  one ends (`project_report` also flags these as `cycle_gap`);
- no running cycle when the calendar says one should be running.

Report these; don't fix them in passing. A date change is part of the
proposal like any other write.

## 3. Work out the capacity

Per-cycle totals mislead when cycle lengths differ, and they mislead
more when a cycle was closed with work done before it started. Compute a
rate per day instead, from the five or six completed cycles that ended
most recently:

| Cycle | Days | Completed | Before start | Effective | Per day |
| --- | --- | --- | --- | --- | --- |
| Sprint N | 5 | 36 | 0 | 36 | 7.2 |
| Sprint N+1 | 7 | 34 | 34 | 0 | (drop) |

- **Days** is `time_used.total` from `list_cycles`. That is the planned
  length, so a cycle closed early gets a rate that is too low. Mark it.
- **Effective** is `completed_count − completed_before_start`. A
  cycle whose effective count is 0 was bookkeeping, not a sprint, so
  leave it out.
- Take the **median** of the per-day rates, not the best one.
- Work out the **project-wide rate** too: the median of the daily
  counts in `completed_by_day_14d` over the last 14 calendar days (the
  list can run longer). Days with no completions are left out of that
  list, so count them as zeros. Use the median, because one
  day of bulk closing (dozens of tickets closed in an afternoon)
  inflates an average.
- **When the two rates differ by more than about 2×**, the rate is the
  person's first decision. Show both, say what could explain the gap
  (overlapping cycles, bulk closing, work closed outside any cycle),
  and recommend one of the two, or a range between them, with the
  reason. A single cycle's rate is not a candidate: that is planning to
  the best cycle. Size the plan to your recommendation, and say which
  cycles go over or under capacity at the other rate. Don't open the
  proposal with a conclusion that holds only at the recommended rate.
- When they agree within about 2×: plan to the lower one, unless the
  cycles you measured overlapped. Then each cycle's rate covers only
  part of what was done on those days, so use the project-wide rate.
- **Who**: when `get_workload` shows one person holding most of the open
  work, the capacity is that person's, and so is the risk. Say so.
- **Intake**: put `created_by_day_14d` next to completions. Where
  tickets arrive about as fast as they close, part of every cycle is
  taken by work that doesn't exist yet. Propose a share to leave
  unallocated (say 20%) and label it as a proposal.

Capacity for a planned cycle = rate × its days × (1 − reserve). Points
are only usable when most tickets carry an `estimate`; otherwise count
tickets, and say which you used.

## 4. Triage

Each `triage` ticket gets exactly one disposition in the proposal:

- **Into a cycle**: name the cycle, plus a priority and an owner.
  `assign_to_cycle` moves it out of Triage on its own.
- **Backlog or Ready**: give a proposed priority. Ready means it could
  be picked up in a cycle as it stands; Backlog means it isn't planned.
- **Duplicate**: run `suggest_duplicates` with the ticket's `issue_key`
  first. A pair matched only by its titles is a guess, so call it one.
  Name the ticket that survives.
- **Close**: say why (out of scope, already done, can't be acted on).
- **Needs work first**: vague, several asks in one ticket, or no clear
  outcome. When the repository shows what already exists, propose the
  rewrite yourself: the title and outcome the ticket should have, and
  what to drop. Otherwise point to the server's `triage_ticket` prompt
  when the host exposes server prompts, or to `ticket.md` beside this
  file. Keep the ticket out of every cycle until it is reworked.

Read each ticket before choosing, not only its title. When a ticket
raises a product question (behaviour changing for existing users, a
default to choose, an open question in its description that another
planned ticket answers), say so in its line and carry the question to
the decisions. Tickets that get the same outcome share one line
("524–529, 534: S19, under epic 390").

## 5. Decide what advances

Go through Backlog and Ready with cycle.md's selection rules, in this
order:

1. Work under a promise due before a cycle ends (`get_timeline`) goes
   into that cycle, or the promise date moves. Say which. The
   `milestone_work_outside_target_cycle` signal lists the misses.
2. Tickets whose blockers are all `settled` (the `settled_blockers`
   signal). A ticket goes into a cycle only when its blocker is done or
   comes earlier in the plan.
3. Priority. An `urgent` or `high` ticket staying in the backlog gets a
   reason written next to it.
4. Traces up to an epic, outcome, or promise (SKILL.md, "Planned work
   traces up").

Put the epic's children into cycles. The epic itself stays out and
appears in the cycle description under Scope. An epic already inside a
planned cycle comes out (`remove_from_cycle`), and its children stay.
An epic whose children are all done (`epics` with `todo: 0` and `done`
> 0) is a candidate to close.

A planned cycle that already has a goal keeps it. Rebalance its tickets
only when its load is over capacity, or when it is missing a ticket its
goal or a promise needs. Moving half a cycle's tickets out turns it into
a different cycle, so propose that as a new goal, openly.

Whatever doesn't make a cycle stays in the backlog, unchanged. Stale
tickets (`stale_issues`) that nobody would pick up are candidates to
close, so list them.

Check the priorities while you are in the backlog. Flag open work still
at `none`, which means nobody decided. Also flag priorities that break
the project's own rule, when its description or a document states one
(for example "high means the next two cycles" on work planned months
out). Propose the corrected priority for each.

## 6. Decide how many cycles

Divide the work that should advance by the capacity per cycle, then put
the result next to the planned cycles and the nearest promise date:

- **Short of cycles**: propose new ones, each starting the day after the
  previous one ends, in the rhythm the project already has. Each gets a
  name, a goal, and dates (cycle.md, "Defining the cycle").
- **Too many cycles**: an empty or thin planned cycle at the end of the
  calendar gets merged or dropped, so propose that.
- **Horizon**: plan tickets concretely for the next two or three
  cycles, or up to the nearest promise date when that is later. Past
  that, a cycle is a theme and dates at most. Filling cycles further out
  turns them into buckets.

Every planned cycle is loaded against its own capacity. A cycle over
capacity gets a cut line (cycle.md, step 7). A cycle well under
capacity keeps its goal: report the room, and offer what could fill it
(the next theme's first tickets, or pulling the calendar forward)
without filling it. Ticket counts hide size, so when a cycle holds a
few large tickets, say that its load is a size risk whatever the count.

## 7. The proposal

Send all of it in one message, in this order. Ask only what blocks the
plan. Where you have a recommendation the person can simply accept
(an owner, a low-stakes priority, a date fix), write it in as the
default and say it can be overridden. Keep the questions to the few
that change the plan.

1. **Bad news first**: calendar problems, promises at risk, high-priority
   work left out, and one person carrying the plan.
2. **Capacity**: the table, the rate you used and its source, intake
   compared with completions, and the reserve.
3. **Cycles**: one row per cycle (existing and new) giving its dates,
   goal, tickets in, tickets out, and load compared with capacity.
   Then the cut line.
4. **Triage**: one line per ticket with its disposition.
5. **Backlog**: what stays and why, grouped (by epic, or by "waiting on
   X"); what to close.
6. **Decisions only the person can make**: the three to five answers
   that change the plan, ranked, each with your recommendation. The
   rate comes first when the two disagreed. Everything else (owners,
   low-stakes priorities, a ticket's own small open question, guesses
   you marked) is already in the plan as a default, listed once in a
   line the person can override.
7. **What gets written**: every write, as the calls you would make, in
   the order of the next section. A plan with no write list hasn't
   finished.

Nothing is written until the person answers. They may take part of the
plan; write only that part.

## 8. Writing it

Send one write per message (the thryx skill, "Batch, do not loop"), in
this order:

1. `create_cycle` for each new cycle, with its description.
2. `update_cycle` for any date fixes from the calendar audit.
3. `update_issues` (up to 20 per call) for triage outcomes: priority,
   assignee, and status for the tickets going to Backlog or Ready.
   Leave the status off for tickets going into a cycle, because
   `assign_to_cycle` sets the scheduled state and replaces whatever you
   set here. Epics whose children are all done close here too.
4. Duplicates: `link_issues` with `duplicate`, and a comment on the one
   that closes.
5. Out of planned cycles: `remove_from_cycle` (up to 20). Out of the
   running cycle, only when the person agreed to a swap:
   `postpone_issue`, one ticket per call, with the reason.
6. Moves between planned cycles: `remove_from_cycle` from the old one,
   then `assign_to_cycle` into the new one.
7. Into cycles: `assign_to_cycle` (up to 20). Report what comes back
   under `promoted`.
8. On each cycle the replan touched, `update_cycle` with
   `description_append` under "**Changed YYYY-MM-DD**": what came in,
   what went out, and why. Rewrite the Scope section only on a cycle
   that hasn't started yet.
9. Propose the downstream updates: the project description's "where it
   stands" (`project-doc.md`) when it names a cycle or date that is no
   longer true, project health, and the promises whose dates moved
   (`roadmap.md`).

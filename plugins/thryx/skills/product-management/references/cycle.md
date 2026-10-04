# Cycles

A cycle (sprint) is a stretch of time with a commitment: one or two
outcomes the team will make true by the end, and the tickets that
deliver them. It isn't a bucket for everything that is Ready. The
cycle's deliverable is its goal, stated so that anyone can check at the
end whether it happened.

## Defining the cycle

- **Name**: the number plus the theme, where the theme names the
  outcome ("Sprint 11: nothing gets slow or large quietly"). A reader
  should be able to tell from the name alone what this cycle is for.
- **Goal**: one or two outcomes that can be checked, such as "a project
  with 5,000 issues opens its list and board" rather than "performance
  work". Tie the goal to the promise it moves. If you can't say the
  goal in a sentence, you have either two cycles or a bucket, so say
  which.
- **Length**: follow the rhythm the project already has (`list_cycles`
  shows past dates). Change it only for a stated reason, and write the
  reason in the description.
- **Dates**: start the day after the previous cycle ends. Point out any
  gap between cycles, because idle days on the calendar are planning
  debt. `project_report` lists gaps between scheduled cycles under the
  `cycle_gap` signal.

## Selecting the tickets

Read these first:

- the goal and the promise dates (`get_timeline`);
- throughput: the `velocity` rows in `project_report` show scope and
  completed per past cycle. Plan to what recent cycles typically
  finished, not the best one. `completed_before_start` means work that
  landed before the cycle began, which flatters the number;
- capacity: `get_workload`;
- carry-over: what the last cycle didn't finish;
- candidates: `list_issues` with `backlog_only`, plus the relations on
  anything you're considering (a blocker marked `settled` is done, so the
  ticket is actually free).

Then choose:

1. **Goal first, tickets second.** Every ticket serves the goal, or is
   named as riding along (a bug, an ops fix, a small request). Keep the
   riders to a small share, so the goal stays the cycle's point.
2. **Check promise dates.** If a promise is due before the next
   cycle ends, its remaining work belongs in this cycle, or its date has
   to move. Say which.
3. **Take tickets from Ready.** A ticket still in Triage gets triaged
   first. `assign_to_cycle` accepts Triage tickets and moves them into
   the scheduled state, but that isn't triage. The exception is a ticket
   the person put into a cycle themselves when filing it: that choice
   was their triage.
4. **Include blocked tickets only when you can unblock them.** Its
   blocker has to be done, or earlier in the same cycle.
5. **Give every ticket an owner before the cycle starts.** Nothing
   should be in progress without one.
6. **Leave slack.** Load to the typical recent cycle, not to what the
   team could do if everything went right.
7. **Show the cut line.** List what nearly made it and why it didn't,
   so the person can swap tickets in or out knowingly.

## The cycle description

The description is how the cycle explains itself to anyone who opens it
mid-way. Write it with these parts:

- **Goal**: the outcome in one or two sentences, and the promise it
  carries.
- **Why now**: what makes this the next thing to do.
- **Scope**: grouped by outcome, each ticket key with a one-line
  reason.
- **Riding along**: the small fixes that don't serve the goal.
- **Out, and why**: what was considered and deferred. Deferred work
  stays in the backlog unchanged, so the decision is easy to reverse.
- **Done when**: the checks you will run at the end.
- **Risks**: preconditions only one person can meet, pending decisions,
  and outside dependencies. A cycle planned behind a precondition that
  depends on one person is how cycles slip, so put that work in the
  second half, or in the next cycle.

The description is a record. Add changes to the plan under a dated
heading ("**Changed YYYY-MM-DD**: two tickets in, one out, because…")
with `update_cycle` and `description_append`, and don't rewrite what the
plan said. `description_section` is only for the parts meant to stay
current, Risks and Done when.

## Proposing and writing

Put the whole plan in one message: the goal, the tickets with owners,
the load compared with recent velocity, the cut line, and the risks.
Wait for an answer. Then:

1. `create_cycle` with the name, description, and dates, when the cycle
   doesn't exist yet.
2. `assign_to_cycle` with up to 20 keys per call. The result names
   tickets promoted out of Triage under `promoted`, so report them.
3. `start_cycle` only when the person says so. A cycle that hasn't
   started is planned, not current.

## During the cycle

Each of these is a proposal first (see "Routines propose" in SKILL.md).

- **Watch the pace.** `project_brief` gives `pace` and how much of the
  window is spent. When the cycle is off track, lead with that.
- **Adding means removing.** When a ticket is added mid-cycle, propose
  which one leaves (`remove_from_cycle`), and record both in the
  description with the reason.
- **Keep statuses honest.** A ticket inside a live cycle that still says
  Backlog is either starting or leaving, so sort it.
- **Pull forward when it finishes early.** Propose moving the next
  planned cycle up (`update_cycle` dates) rather than leaving idle days,
  and record that in both cycles' descriptions.

## Closing the cycle

1. **Check the goal.** Was the Done when met? Answer yes or no first,
   then the detail.
2. **Decide each unfinished ticket** with the person: roll it into the
   next cycle, send it back to the backlog, or cut it.
3. **Carry out those decisions in this order**, because `complete_cycle`
   with `rollover_to` moves everything still unfinished:
   1. cut: comment why, then close or cancel the ticket;
   2. back to the backlog: `postpone_issue`;
   3. the rest: `complete_cycle` with `rollover_to` set to the next
      cycle.
4. **Write the retrospective** into the cycle with `description_append`:
   goal met or not, what shipped, what slipped and why, the scope and
   completed numbers, and one thing to change next time.
5. **Propose the updates downstream:** the Roadmap's promises,
   criteria, and outcomes (`references/roadmap.md`), the "where it stands" part of the
   project description (`references/project-doc.md`), and then the next
   cycle's plan.

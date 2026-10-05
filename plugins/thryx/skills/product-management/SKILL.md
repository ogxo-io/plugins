---
name: product-management
description: Use when the user asks for product or project management work in ThryX - define, plan, review, or close a cycle or sprint; replan or rebalance the cycles, triage the backlog, or redistribute open work across sprints; what's the status, a standup, weekly review, or post-release check; write a spec or PRD, record a decision (ADR), or write or refresh the project overview; break down an epic or rewrite a vague ticket; build or audit the Roadmap a client reads (releases, promises and their criteria, outcomes, the public timeline link), including building a project's Roadmap from what its repository has shipped and plans.
---

# Managing a product with ThryX

This skill is about doing the PM part of the work well: writing it down,
keeping it current, following it up, and telling people the truth about
where things stand. The thryx skill covers how the tools behave, and
this skill leaves the mechanics to it, apart from the Roadmap's own
mechanics in `references/roadmap.md`. Read both.

## You are not a persona

The person who opened the session is still in charge. This skill tells
you how to do PM work well when they ask for it. It doesn't turn every
turn into a planning turn. If they asked you to move a ticket, move the
ticket. Offer the rest (a follow-up, a doc, a board fix) in one line at a
natural pause, and drop it if they don't take it up.

**Routines propose; writes wait for an answer.** Every routine in the
references (a review, a cycle plan, a board audit, a release check) ends
in a proposal: what you would change, where, and why. Nothing is
written, whether a status, a health, a date, a ticket, or a comment,
until the person answers. Where a reference says "update" or "set", read
it as "propose, then write once agreed".

## You have the repository, so use it

ThryX's own assistant plans from the tracker alone. You can also read the
code, the git history, release tags, the CHANGELOG, and the docs in the
repo. The tracker records what was intended and decided. The code shows
what exists and what shipped. Where they disagree, you have a finding, so
report it. Say which source each claim came from, and never present a
guess about the code as something you read.

## Pick the work, then read its reference

| When the work is | Read |
| --- | --- |
| Writing or improving a ticket, or breaking down an epic | `references/ticket.md` |
| A spec for a feature (a PRD) | `references/prd.md` |
| A decision and the reasons for it (an ADR) | `references/adr.md` |
| The page that says what the project is | `references/project-doc.md` |
| Defining a cycle: its goal, its tickets, its description, closing it | `references/cycle.md` |
| Replanning across cycles: triage, what advances, what stays in the backlog, which cycle each ticket goes to, whether more cycles are needed | `references/replan.md` |
| Standup, weekly review, after a release | `references/follow-up.md` |
| The Roadmap (releases, promises, criteria, outcomes, the public link), anything a client reads, or a Roadmap built from the repository | `references/roadmap.md` |

The server also ships prompts for some of this work (`write_ticket`,
`plan_cycle`, `organize_project`, `roadmap`, `macro_board`,
`project_status`; the
thryx skill lists them). They are the procedures ThryX's own assistant
follows, written from the tracker alone. Use a prompt when it fits and
add what the references here cover and it doesn't: the repository, and
proposing before writing.

## Where each thing lives

Every fact has one home. Everything else links to it. Don't paste a
PRD into its tickets; name the document in the epic and the epic in the
document.

- **Project description** (`get_project`, `update_project`
  `description`): a short summary that the owner keeps up to date. Every
  agent that files work in the project reads it first, ThryX's own
  assistant included.
- **Documents**: long-lived pages such as the overview, PRDs, ADRs, and
  runbooks, tagged so they can be found (`prd`, `adr`, `runbook`,
  `architecture`; reuse the tags `list_document_tags` returns).
- **Tickets**: one outcome each. Use the type `decision` for a choice
  still open and `research` for a question to answer. An epic groups
  tickets under an outcome.
- **Comments**: what was found or decided on a ticket, so the next
  person doesn't have to dig for it again.
- **Cycles**: what the team committed to for a stretch of time. The
  cycle description holds the goal and, at the end, what happened.
- **The Roadmap**: releases, promises with their criteria, and
  outcomes; the timeline the client reads.
- **Project health** (`update_project` `health`): how the project is
  going (`on_track`, `at_risk`, or `off_track`), always with a reason.
  You propose it and the person sets it.

## Opinions worth holding

- **Write for the reader who has only this page.** That may be a person
  next month or an agent with no context. If they would need to ask you
  something, the page isn't finished.
- **Outcomes over activity.** A title says what will be true when the
  work is done. A status report says what changed for users, not how
  busy the team was.
- **Planned work traces up.** When planning or reviewing, check that
  each piece of the plan belongs to an epic, the epic backs an
  outcome, and the outcome belongs to a promise. A planned
  item that traces to nothing is either not worth doing or a gap in the
  plan, so say which. Not all work traces up: bug fixes, operations, and
  internal debt often don't, and that's fine. Don't raise this on
  ordinary ticket work.
- **Write decisions down the day they are made.** A decision that lives
  only in a conversation will be argued again.
- **Bad news goes first.** Slipping dates, stuck work, and missing owners
  lead the report, and each comes with a proposed fix.
- **Don't invent what the person didn't give you.** Priorities, dates,
  estimates, owners, and success measures are theirs to set. Ask, or
  mark your suggestion as a proposal.
- **Close the loop in the tracker.** Every routine ends with what it
  wrote back and where: a comment, a cycle note, a health update, or a
  document. A summary left only in chat is lost when the session ends.

# Recording a decision (ADR)

An ADR (architecture decision record) records one decision, the reasons
for it, and what it costs. Write one when a choice is expensive to
undo, or when someone will ask "why is it like this?" a year from now:
architecture, a dependency, a data model, a protocol, or a team process.
A small choice that is easy to reverse doesn't need one.

## While the decision is open

Track an open choice as a ticket with `issue_type: decision`. The
ticket carries the question, who decides, and by when. The options and
evidence go in its description or comments. The ADR is written when the
decision is made, and the ticket closes with a comment naming the ADR.

## Structure

Title the ADR with the decision itself, not the topic: "Job leasing uses
Postgres advisory locks", not "Job queue".

- **Status**: Proposed, Accepted, or Superseded by (another ADR). Add
  the date and who decided.
- **Context**: the problem, the constraints, and the forces pulling in
  different directions. Base it on facts you checked in the code and the
  tracker, and name the files and tickets.
- **Options considered**: each option with its real pros and cons,
  including "do nothing". An ADR that shows only the winner can't be
  checked.
- **Decision**: what was chosen, in one or two sentences.
- **Consequences**: what gets easier, what gets harder, what is now
  ruled out, and the follow-up work this creates, proposed as tickets.
- **Revisit when**: the condition that would reopen it, such as a load
  level, a vendor change, or a date.

## Rules

- **Don't rewrite an accepted decision.** When it changes, write a new
  ADR that supersedes the old one. Then change only the old one's status
  line (`update_document` with `body_section`, after showing the
  change). Keeping the history is the point.
- **Keep one source of truth.** If the repo already keeps ADRs (for
  example in `docs/adr/`), ask which place is canonical before writing
  in the other. Two drifting copies are worse than either one alone.
- **Tag it** `adr`, and add a comment naming it on each ticket it
  governs.
- **Use it.** When a request conflicts with an accepted ADR, name the
  ADR and ask before going ahead (the thryx skill says the same about
  any recorded decision).

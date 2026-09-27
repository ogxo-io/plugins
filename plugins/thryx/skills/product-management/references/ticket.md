# Writing a ticket

A ticket is read by someone who has only the ticket: a teammate next
week, or an agent picking it up cold. Write it whole in the create call,
not as a one-line placeholder unless the person says a placeholder is
enough. Before filing, read `get_project` for what the product is today
and search for duplicates (the thryx skill has the rules).

## The shape

This is the same shape ThryX's own assistant uses, so tickets filed from
either place read alike.

- **Title**: what will be true when the work is done, as a sentence
  with the product as its subject, such as "A project can be archived" or
  "Retries back off after a rate limit". It is not a command to whoever
  picks it up: no "Add", "Implement", or "Fix".
- **Today**: what the product does now, and what exists nearby.
- **Should**: the behaviour asked for, in one paragraph.
- **Done when**: three to six checks a person could make, such as what
  appears, what is refused, or what a client sees.
- **Not in scope**: the neighbouring work this ticket doesn't cover.
- **Open questions**: anything you had to choose that the person didn't
  say. Repeat them in your reply.

## What you add because you can read the code

ThryX's own assistant is told to leave file paths out because it can't
see the code. You can, so add:

- **Where**: the files, modules, endpoints, or tables involved, as
  pointers rather than instructions ("the retry loop is in
  `src/net/client.rs`"). Include only paths you opened in this session,
  and say which commit or branch. A confident wrong path costs more than
  none.
- **Seen** (bugs): steps to reproduce, expected against actual, the
  error or log line quoted exactly, and the version or commit. Attach
  the screenshot or log as evidence with `attachments` (the thryx skill
  gives the format) and describe what it shows.
- **Links**: the pull request, GitHub issue, or advisory, using the
  matching `link_*` tool, plus the document the ticket implements.

Keep the product-level sections first. Someone who never opens the code
should still understand the ticket from Title through Not in scope.

## Fields

- `issue_type` follows from the content: `feature` for a capability that
  doesn't exist yet, `bug` for wrong behaviour, `technical_debt` for
  internal cost, `research` for a question to answer, `decision` for a
  choice to make, and `epic` for a group of tickets. "Task" in the
  person's sentence means "file this", not the type.
- Leave `priority` out unless the person gave one. A priority you picked
  looks exactly like one they chose.
- Use labels only when the project already uses them for this kind of
  work.
- Name what you chose in your reply, so a wrong pick takes one click to
  fix.

## Sizing

One ticket covers one outcome that can be reviewed and shipped on its
own.

- If Done when needs more than six checks, or covers parts that could
  ship separately, split it.
- If two tickets can't be tested without each other, merge them.
- A ticket that someone has held in progress for more than a cycle is
  usually too big. Say so at the weekly review.

## Epics

An epic is an outcome with an end, not a bucket. "Payments" is a
bucket; "Customers can pay by card" is an epic. Give it the same shape
as a ticket, with its Done when stated at the level of the whole
outcome, and close it when that is met. When an epic implements a PRD,
name the document in the epic and the epic in the document. To break an
epic down, create the epic first, then its tickets in one
`create_issues` call with `parent_issue_key`.

## Improving an existing ticket

A ticket is someone's writing. To add to it, use `update_issue` with
`description_append`, and to change one part, use `description_section`
with that heading. Replace the whole description only when asked to.
Show what you would change first. If a vague ticket needs the
reporter's answer, ask in a comment rather than guessing in the
description.

## Checklist before filing

- Could someone do this with only the ticket in front of them?
- Does the title state an outcome?
- Could each Done when check be verified by someone who didn't write it?
- Did you open every path you named in this session?
- Did you search for a duplicate?
- Does the ticket say where it belongs? Settle its state, cycle, and
  epic as in the thryx skill's "Settle where a new ticket goes".

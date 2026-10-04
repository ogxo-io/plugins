# Writing a PRD

A PRD (product requirements document) gets a feature agreed before
anyone builds it: what problem it solves, for whom, what "done" means,
and what is left out on purpose. Write one when a feature spans several
tickets, needs more than one person to agree, or will be argued about
later. A bug fix or a one-ticket change doesn't need one.

## Before drafting

- Look for an existing one: `search_workspace` finds documents by
  title, body, and tag, and `list_documents` with `tag: "prd"` lists one
  project's PRDs (if the project has no `prd` tag yet, the refusal lists
  the tags it does use). Extending a PRD beats writing a rival one.
- Read what exists: `get_project`, the related epics and tickets, and
  the code the feature touches. What the product does today should be
  something you checked, not something you remember.
- Ask for what you can't know: who asked for it and why, the deadline,
  and how success will be measured. Don't make up metrics or dates. Mark
  them as open questions for the person to answer.

## Structure

Put a one-line status and date at the top, such as `Status: Draft,
YYYY-MM-DD`, followed by the owner. Status moves through Draft, In
review, Approved, and Superseded by (another PRD).

1. **Problem**: who has it, what it costs them, and the evidence
   (tickets, support threads, data, quotes). If there is no evidence,
   say so.
2. **Users and what they are trying to do.**
3. **Goals**: outcomes you can measure. **Non-goals**: what this work
   won't do, stated plainly, which prevents most scope arguments.
4. **Success measures**: how you will know it worked, and when you will
   check.
5. **Today**: what exists now, from the code and the product. Name the
   limits you found in the code.
6. **Proposal**: behaviour and flows from the user's side, not the
   implementation. A mermaid diagram renders in ThryX documents.
7. **Scope**: what ships first, what comes later, and what is out.
8. **Risks and dependencies**: other teams, clients, data migrations,
   and anything that has to be decided first (link the ADR or the
   `decision` ticket).
9. **Open questions**: each one with an owner.
10. **Rollout**: flags, migration, communication, and what the client
    is told.
11. **Links**: the epic, promise, related ADRs, and designs.

## From draft to tracker

1. Draft it in your message and wait for an answer.
2. `create_document` titled by what it answers ("PRD: customers can pay
   by card"), then `tag_document` with `prd`.
3. Once it's approved, break it into tickets (`references/ticket.md`)
   under one epic. Name the PRD in the epic, and list the epic in
   Links.
4. If it's client-facing, propose the outcome and promise
   (`references/roadmap.md`).

## Keep it alive

When scope changes during the build, update the PRD's Scope section, not
only the tickets. Otherwise the PRD becomes fiction. `update_document`
with `body_section` changes one heading. Show the change first (the
thryx skill's confirmation contract applies). When the work ships,
propose setting the status line and record whether the success measures
were met when you checked.

# Milestones and the macro board

Read this before you build, audit, or write copy for a project's
milestones or macro board. The thryx skill's short section covers only
what the everyday ticket flow needs.

## What they are

Two layers sit above the tickets. A **milestone** is a dated checkpoint
on the project's timeline. The **macro board** is the list of
deliverables (macro items) that a client reads in the partner portal:
a title, a public description, a status, a target date, and a progress
number. Tickets back macro items and macro items belong to milestones.
The client sees the deliverable and never the tickets behind it. A
board that is empty, stale, or at 0% tells the client nothing is
happening, however busy the tracker is. `project_structure` reports a
project with no milestones or an empty macro board as a gap.

## What the client sees

- Creating shows nothing. `create_milestone` and `create_macro_item`
  both create the row hidden. Showing one is a separate
  `update_milestone` or `update_macro_item` with `partner_visible: true`,
  and that call asks for `confirm_irreversible`. Treat showing as the
  user's decision, one item at a time.
- A shown macro item whose milestone is hidden or canceled appears to the
  client without its milestone. Show the milestone first, or together
  with its items.
- A shown milestone puts its title, description, status, target date,
  and progress in front of the client.
- Clients can comment on a shown macro item only when
  `partner_comments_enabled` is on. No tool on the MCP list reads those
  comments; for the client's replies, send the user to the web app.
- The tool list has no delete for either one. Retire a milestone with
  status `canceled` and a macro item with `partner_visible: false`.

## Progress is computed and status is claimed

A macro item created over MCP measures its progress from the tickets
linked to it with `link_macro_item_issues`: completed tickets over
linked tickets, not counting canceled or archived ones. With no tickets
linked, it reads 0%. A milestone's progress counts every distinct ticket
linked through its macro items (a ticket linked twice counts once), and
marking the milestone `completed` pins it at 100%. Status on both is set
by hand: nothing moves an item to `completed` when its tickets finish.
That leaves the agent three jobs:

- **Link every item.** An item with no tickets stays at 0% no matter how
  much work ships. `link_macro_item_issues` returns the new
  `progress_percent`, so report it.
- **Link new scope.** A ticket filed under an epic that backs a
  deliverable doesn't count toward that item until you link it, and
  until then the item looks further along than it is.
- **Reconcile status with the number.** An item at 100% that still says
  `in_progress`, or one marked `completed` at 40%, is telling the client
  something false. Point it out and propose the status change. Don't
  change it quietly.

## Keeping client copy clean is mostly on you

Titles and public descriptions on macro items are refused when they
name a ticket key (`<PROJECT_KEY>-<number>`). That is the only check
the server makes. Milestone titles and descriptions get no check at all,
and the client reads them once the milestone is shown.

Everything a client can read, whether macro items, milestones, or the
project's public description, must also never contain:

- another customer's or company's name;
- internal shorthand: review names, table and function names, code
  fragments, branch names;
- planning detail such as sprint numbers or "the owner's call";
- anything that is not the client's business.

A milestone description is often written as internal planning text
first and shown later. Before showing a milestone, or when auditing
one that is already shown, read its description as the client would,
and propose a client version. Planning detail belongs in the epic or an
internal document instead.

## Use the repository you are working in

ThryX knows the tickets, and the codebase knows what the product does
and what has shipped. An agent working in the repo can read both, which
ThryX's own assistant cannot. Use that to make the board match reality.
Name the files, tags, and pull requests a proposal came from so the
user can check them.

- **Find deliverables in the product, not the backlog.** The README,
  user docs, the list of pages, routes, commands, or public API
  endpoints, and feature flags describe the product in terms its users
  recognise. That makes better titles than epic names. Match each one
  to the epics and tickets that build it.
- **Take milestones from how the project ships.** Release tags, the
  CHANGELOG, version fields in manifests, and roadmap documents show
  what the project calls a release, a beta, or a launch. Line milestones
  up with those. Take target dates from a planned release or from the
  pace in the git history. When neither exists, say the date is a guess.
- **Check "done" against the code.** Before calling an item completed or
  telling the client something shipped, check `list_pull_requests` for
  its tickets, and check whether the change is in a release tag. Merged
  is not released. When the project cuts releases, done for the client
  means it is in a release they can use. Flag a ticket marked completed
  that has no merged pull request.
- **Find what the board misses.** Changes merged since the last release,
  or listed under "Unreleased" in the CHANGELOG, that a user would
  notice but that sit on no item's tickets are either missing from the
  board or deliberately left off it. Ask which, and link or file them.
- **Draft copy from release notes, not from commits.** CHANGELOG entries
  and pull request descriptions come closer to the client's language
  than ticket titles do. Still translate them: leave out file, branch,
  library, and service names, internal codenames, and ticket keys. The
  repo is internal, so never quote it into client copy as written.
- **Hold back security fixes.** Say nothing about a vulnerability or its
  fix in client copy until its advisory is public. Before then, describe
  the item by the outcome ("hardening", "reliability") or leave it off.
- **Note where the repo and ThryX disagree.** When a roadmap in the repo
  and the milestones in ThryX disagree, say where and ask which is
  right. Don't sync either one quietly.

## Building the board

This is normal right after an import, or for a project that has only
ever been tracked internally.

1. Read the work first: `project_structure`, the open epics (see "Settle
   where a new ticket goes" in the thryx skill), `list_milestones`, and the
   repository sources above.
2. Propose everything in one message and wait for an answer. That means
   milestones as dated checkpoints the client would recognise. It also
   means deliverables as outcomes, usually one per epic or feature
   cluster rather than one per ticket ("Customers can pay by card", not
   "Stripe webhook handler"). Give each deliverable a public
   description, its milestone, a target date, and the tickets that back
   it. Name the tickets that fit no deliverable. Not all work is the
   client's business, and leaving it off the board is fine.
3. Once the user agrees, write in order: `create_milestone`, then
   `create_macro_item` with `milestone_title`, then
   `link_macro_item_issues` (at most 20 keys per call). Everything is
   still hidden at this point.
4. Ask separately which milestones and items to show.

## Checking the board's health

When asked for status, before a client meeting, or after a release,
read `list_milestones` and `list_macro_items` and lead with what is
wrong:

- a milestone past its target date and not `completed`;
- a shown item with no tickets linked, or with an empty public
  description;
- progress and status that disagree;
- an item whose target date falls after its milestone's;
- a shown item under a hidden milestone;
- a shown milestone whose description reads as internal planning text,
  or names ticket keys or another customer;
- an item waiting on the client with nothing that says so, or one
  flagged as waiting when it no longer is;
- an item that reads as shipped while the code behind it isn't in a
  release, or a release that shipped something no item mentions.

## Waiting on the client

Setting status `waiting_for_partner` together with
`partner_action_required` is how the board tells the client the ball is
in their court. When you propose setting them, draft the public
description to say what you need from the client: a decision, access,
content, or sign-off. Propose clearing both once the client has
delivered.

## Writing what the client reads

Before rewriting an item, call `get_macro_item` and read the tickets
behind it. A summary written from the old description repeats whatever
has gone stale. Write about outcomes in the client's terms: what they
can do now, and what is waiting on them. Mention only work that is
theirs. Draft the copy in your message, say whether the item is already
shown (the result of `update_macro_item_summary` carries
`partner_visible`), and wait.

Filling an empty description, or changing status, dates, milestone,
hiding, or the partner flags, goes through without confirmation.
Replacing copy someone already wrote, or showing a hidden row, asks for
`confirm_irreversible`. ThryX keeps no earlier version of a milestone or
macro item that you could restore.

The project has client copy of its own: `update_project` with
`public_description` is what the client reads first on the client view
and the partner portal. It follows the same rules: no ticket keys,
outcome language, draft first. Replacing text someone wrote asks for
`confirm_irreversible`, and ThryX keeps no earlier version of it either.
Keep it consistent with the milestones the client can see.

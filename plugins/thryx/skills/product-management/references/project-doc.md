# The page that says what the project is

A project needs a page that a newcomer, a stakeholder, or an agent can
read to learn what the project is, what exists, and where it stands.
ThryX keeps it in two layers.

## The project description, the short layer

`get_project` returns the description the owner keeps. Every agent that
files work in the project reads it before filing, ThryX's own assistant
included. A stale description therefore produces badly aimed tickets.
Keep it to about a screen:

- what the product is and who it is for;
- what exists today, as the main capabilities;
- where the work stands: the current promise, the current cycle's
  goal, and the biggest risk;
- what comes next;
- links to the overview document, the active PRDs, and the key ADRs.

Edit the smallest part that changed. Keep "where it stands" under its
own heading, so a refresh is one `update_project` call with
`description_section`; `description_append` adds at the end. Neither
asks for confirmation, so the check is on you: read the current text
with `get_project`, show the change, and write it only once the person
agrees. `description` replaces the whole text and asks for
`confirm_irreversible` when there is text to replace (see the thryx
skill's contract). The client reads `public_description`, a separate
field covered in `references/roadmap.md`.

## The overview document, the long layer

This is a document titled by what it answers, such as "Overview: what
Acme Billing is and how it is built", tagged `architecture`. Cover:

- **Purpose**: the problem, the users, and what success looks like.
- **What exists**: capabilities, the surfaces people use (pages, API,
  commands), and integrations.
- **How it's built**: the main components and how data flows between
  them, as a mermaid diagram (it renders in ThryX documents), plus
  environments and where things run.
- **How work flows**: the workflow states and what each one means,
  cycle length, definition of done, how releases are cut, and who
  decides what.
- **Glossary**: the project's words, especially the ones that mean
  something different here than elsewhere.
- **Index**: links to the PRDs, ADRs, and runbooks.
- **Last reviewed**: a date at the top.

## Build it from both sources

- **From the repo**: the README, manifests and dependencies, the
  directory layout, CI and deploy configuration, and `docs/`.
- **From ThryX**: `project_structure`, `get_timeline`, the open
  epics, `list_documents`, and `list_statuses`.
- Say which source each part came from. Where you can't tell, write
  "unknown" and ask, rather than smoothing it over. Where the two
  disagree (a README feature with no ticket, an epic marked done that
  the code doesn't have), list it as a finding.

## Keep it current

Update the description's "where it stands" part when a cycle closes and
after each release (see `references/follow-up.md`). Review the overview
when a new ADR is accepted or the architecture changes, and bump the
"Last reviewed" date.

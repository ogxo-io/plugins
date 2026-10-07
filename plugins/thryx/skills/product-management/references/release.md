# Preparing and shipping a release

Read this to prepare a release, write its notes, ship it, or check it
afterwards, along with `roadmap.md` for promises, criteria, and
audiences. Tool behaviour changes as ThryX does: when a schema
disagrees with this page, the schema wins. Every write takes effect at
once, in the token owner's name. A `planned` release is a real record
the team can see, not a staging area.

## Keep the records apart

Most release mistakes come from treating one of these as another.

| Record | What it means | What it does not mean |
| --- | --- | --- |
| Cycle | A time box of work, operations and research included | Completing it ships nothing |
| Git tag | The code that was cut | Pushing it changes nothing in ThryX |
| Release | Version, date, audience, state, tickets, notes | `planned` is not shipped |
| Ticket's `release` | The release it is meant to ship in | Assignment is not delivery |
| Ticket's `shipped_in` | What it actually shipped in, frozen at shipment | Later edits to the ticket don't change it |
| Promise | An outcome committed to a client, with criteria | Its tickets being done doesn't make its criteria true |
| Carried promise | A promise listed on a release | It isn't kept, gated on, or shown wider by being listed |
| Gate | One promise or one criterion holding the release back | It is a blocker to satisfy, not a setting to clear |
| Notes | The team's Markdown about the release | Never shown to partners or the public |
| Announcement | Copy for one channel and audience | Saving notes posts nothing |

## The tools

| Tool | What to know |
| --- | --- |
| `list_releases` | State, audience, gate configuration, carried promises, ticket counts (`work_done`, `work_total`), and a notes preview for each release. Name one `release` to get its whole `notes`. |
| `get_timeline` | Whether each gate is open, and with `audience` set to `partners` or `public`, what that reader sees. |
| `get_issue` | A ticket's `release` and its `shipped_in` list, though the tool description doesn't mention either. |
| `list_cycle_issues`, `list_pull_requests` | What the cycle held, and the PRs behind each ticket. |
| `create_release` | `version` (unique in the project, at most 60 characters), optional `release_date`, `audience`, `public_name` (120), `summary` (2,000), `sort_order`. It takes no state: only `set_release_state` ships it. The audience defaults to `internal`. A `partners` or `public` release is on their timeline from the moment it exists. |
| `update_issue`, `update_issues` | Set `release` to a version or id, or `null` to clear it. At most 20 tickets per batch. `create_issues` has no per-ticket `release`: create, then assign. |
| `update_release` | Send only the fields that change. `notes` replaces the whole body (at most 50,000 characters) and may name only tickets this release carries or shipped. An empty string clears a field; `null` clears the date. ThryX keeps no revision. |
| `set_release_promises` | Replaces the whole list. An empty list clears it. |
| `set_release_gate` | `milestone` alone gates on a whole promise; `milestone` plus `done_when` on one criterion; neither clears the gate. `text` (300 characters) is the line a client reads. |
| `set_release_state` | `planned`, `cutting`, or `shipped`. Only with `shipped`: `release_date` to record the actual date, `notes_seed`, and `unfinished`. Refused while the gate is open. A shipped release cannot be reopened. |
| `archive_release` | Takes the release off the active timeline and keeps its shipment history. An unshipped release with open tickets needs `unfinished`. |
| `delete_release` | Nothing over MCP brings it back. Archive a release that has history instead. |

`notes_seed` is `snapshot` by default: when the release has no notes, it
drafts them from the shipped tickets. `blank` leaves them empty. Notes
already written are never replaced. `unfinished` decides the open tickets
assigned to the release: `{"action": "clear"}` takes them off it, and
`{"action": "move", "release_id": "<version or id>"}` moves them to
another active release that hasn't shipped. Their statuses stay as they
are, so keep those honest.

Each limit and behaviour above is from the tool descriptions the server
publishes; check them there when one surprises you.

## From the tag to a verified shipment

### 1. Read and reconcile

Resolve the workspace and project, then read the project, its releases,
the cycle's tickets, and the promises in play with their criteria. In the
repository, compare the tag with the one before it: the commits, the
merged PRs, the CHANGELOG or release notes the project keeps. Confirm the
range is not empty before you draw anything from it.

Look for the mismatches, and report each one:

- tickets marked done that the tag doesn't contain;
- changes in the tag that no ticket covers, often a fix made outside the
  cycle;
- cycle work that ships no code, such as operations or research, which
  belongs in the retrospective but not in the release;
- a release record that is missing, or that already exists for this
  version (review it; don't create a second one);
- release documentation that is missing or stale: that is a finding, not
  source copy.

Keep the steps of getting code out apart. The tag was pushed, the build
was published, and the deploy succeeded are three claims, each needing
its own evidence. Say which you checked.

### 2. Draft the whole release

Put one draft in front of the person:

- the version, its tag and commit, and the date (actual or proposed);
- the audience, and for `partners` or `public`, the public name and
  summary written as client copy, with no ticket keys;
- the tickets it includes, and the ones you left out and why;
- the promises it carries, which of them it completes, and which it only
  moves forward. Done tickets don't make criteria true: propose marking
  a criterion only with evidence for it;
- the gate, if any, and whether it is open;
- the notes;
- what you couldn't verify.

### 3. Prepare the record

Once the person agrees, or asked you to prepare the release in the first
place:

1. `create_release`, `internal` unless they chose another audience.
2. `update_issues` to assign the tickets. Read the returned rows and
   per-item errors: overall success doesn't mean every ticket was
   assigned.
3. `set_release_promises` with the existing list plus any new promise.
4. `set_release_gate`, when the person wants the release to wait.
5. `update_release` with the notes. Assign a ticket before you cite it.
   When a note names a ticket the release doesn't carry, fix the note;
   don't attach the ticket to make the check pass.

Read the release back with `list_releases` and report what was written
and what failed.

### 4. Ask once to ship

Preparing the release doesn't authorize shipping it. Ask with the
finished draft in front of the person: the release, the date, the
audience, the count and keys of the tickets that will be recorded as
shipped, the carried promises, the gate and whether it is open, and what
happens to unfinished tickets. Say plainly that shipping freezes what was
delivered and cannot be undone. When they already told you to ship, that
is the answer.

`confirm_irreversible` is not this answer; it records that you asked.
When the host stops the call (a permission prompt, an auto-mode check,
Codex's approval policy), report what it refused and why, and leave the
release where it is. Waiting, another tool, or deleting and recreating
the release is not a way around it. Report the state the release is
actually in: prepared and `planned` is a result, not a failure.

### 5. Ship and check

`set_release_state` with `shipped`, the actual `release_date`, and
`unfinished` when open tickets are assigned. When the gate is open,
satisfy it with evidence; don't clear it, delete its promise, or change
ticket statuses to get past it.

Then check, rather than trust the response:

- `list_releases` for this release: state, date, audience, notes kept or
  seeded, promises still carried;
- `get_timeline`: the gate satisfied, and what each audience now sees;
- `get_issue` for each ticket you expected to ship: `shipped_in` names
  this release;
- the unfinished tickets moved or cleared as agreed.

No tool lists a release's tickets, and `work_done` matching your count is
not proof the right tickets shipped. Check by key, and say which tickets you could
not check.

### 6. Close the cycle separately

Completing the cycle is its own step, with its own yes; follow
`cycle.md`. The retrospective names what shipped in the release and,
apart from it, the operations and research work the cycle did. When
shipping is still waiting on an answer, say so in the retrospective and
append the outcome once it is settled.

## Announcements

The notes are for the team. An announcement is a separate draft for one
channel and audience: lead with what the user can now do, group the rest,
and link the release only where that audience can open it. Leave out
confidential tickets and the detail of unreleased security fixes (see
`roadmap.md`). There is no tool that posts a release to Slack or anywhere
else: hand the draft to the person to post, and never paste the internal
notes into a shared channel.

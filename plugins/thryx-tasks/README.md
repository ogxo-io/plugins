# thryx-tasks

A panel beside the Claude Code chat that shows your ThryX board: the active
sprint or all open tasks, yours or everyone's, split into Doing, Review and Up
next, with the sprint's progress. Selecting a task opens a card with its pull
requests, checks and description, and a button that puts it in your prompt so
you can ask Claude about it.

```
KLC Sprint 109 ▓▓▓▓▓▓▓▓░░░░ 45/64 · 3 work days left · 14:32
Sprint All │ Me Everyone │ +up next │ KLC·klever ▾ ⟳ refresh auto ✓

🚧 Doing 1
🟡 KLC-2874 · 1pt · Improve Security · 19h
   The cost of verifying requested transactions during sync is
   measured, and the accounts lock is not contended by it

📋 Up next 3
🟠 KLC-2397 · Ready · 2pt · Sustentação KleverChain
   Validator: silently abstain on local SC execution timeout…
```

Claude Code only. The panel is a Claude Code hooks module (early access in
Claude Code). Codex does not load hooks modules, and this plugin's Codex
package has no skills and its hooks turned off. Grok Build is untested.

## Install

```bash
claude plugin marketplace add ogxo-io/plugins
claude plugin install thryx-tasks@ogxo
```

It depends on the `thryx` plugin, which installs with it. Connect ThryX first
with `/thryx:connect` (see the [thryx README](../thryx/README.md)). The panel
calls the `thryx` MCP server that command adds, or the claude.ai ThryX
connector (`claude.ai ThryX`) when that is the one connected: it tries the
`server` setting's name first, then those two, and keeps the first that
answers. The install may say its
settings are not set yet; each one has a default, listed under
[Settings](#settings), and none needs setting to start.

## Use

On first open the panel asks you to pick a board: **Board ▾** lists every
project in every ThryX workspace your token reaches. The panel opens by itself
in each new session when the terminal is wide enough to dock it beside the chat
(144 columns); otherwise run `/thryx-tasks`.

The line under the header holds the filters; each has a hotkey.

| Control | Key | What it does |
|---|---|---|
| **Sprint** / **All** | `s` / `a` | The project's active cycle, or every open ticket in the project |
| **Me** / **Everyone** | `m` / `e` | Your tickets in Doing, Review and Up next; or one line per person with their counts, which opens to their tickets |
| view | `v` | Cycles doing+review → +up next → +done (done shows in Sprint only); changes the view without reloading |
| **Board ▾** | `b` | Pick another workspace and project |
| **⟳ refresh** | `r` | Reload now (ignored within 10 seconds of the last one) |
| auto | `o` | Whether the panel opens by itself at session start |
| a task | | Opens its card: type, labels, pull requests with review and check state, the start of its description |
| **Ask Claude** (card) | `c` | Appends `About ThryX ticket KEY: ` to your prompt; Claude reads the ticket with the ThryX tools |
| **Copy key** (card) | `k` | Copies the key, or its link when `issueUrlTemplate` is set |
| **Close** (card) | `x` | Closes the card |

Up next is the not-started tickets in the active sprint. In **All**, the other
not-started tickets (Triage, Backlog, Ready outside the sprint) go to Backlog,
which folds to one line (`🗃️ Backlog 12 ▸`) until you open it; with no sprint
running they all stay in Up next. Up next and Backlog are sorted by priority
and list five, then "+N more"; Doing and Review are sorted by last change. A row shows the priority (⛔ when blocked),
the key, the estimate, the epic and how long since it changed. Done folds to
one line (`✅ Done 14 ▸`) until you open it; its rows drop the priority and
are dimmed. When every ticket in a section has the same epic, the section
title names it once instead of each row. A key line at the bottom of the panel spells
out the priority icons.

The same from the prompt:

```
/thryx-tasks [sprint|all] [me|everyone] [active|open|done]
             [board <workspace>/<KEY> | board <KEY> | boards | board default]
             [refresh] [auto on|off] [permissions]
```

When a reload finds that a ticket moved (into Review, to Done, back to Up
next), was added, or became yours, the panel shows a toast and marks the
row (`• moved to Review`) for 15 minutes. Changing a filter or the board
reports nothing.

The hint line under the prompt ends with your own open work on the board and
the sprint's time left, dim, for example `· KLC 🚧1 👀0 📋3 · S109 3wd`, also
while the panel is closed. Set `statusLine` to `off` to drop it. Claude Code
leaves it out when the terminal is too narrow, and draws it in the terminal
only.

Filters and auto-open are saved and come back in the next session. The chosen
board is saved per project (the session's project root), so picking a board in
one project leaves the others on theirs; a project with none saved uses the
`workspace` and `project` settings. The panel reloads every 5 minutes while it is open, or always when
the hint line summary is on.

Icons: 🚧 doing, 👀 review, 📋 up next, 🗃️ backlog, ✅ done, ⛔ blocked; priority
🔴 urgent, 🟠 high, 🟡 medium, 🔵 low, ⚪ none; on a pull request 🟢 open,
📝 draft, 🟣 merged, ⚫ closed; ⏳ marks a started ticket idle for more than 3
days. Set `icons` to `plain` for ASCII markers.

## Auto mode (Claude Desktop)

In Claude Desktop with auto mode on, the panel has shown "the server-side
auto mode classifier gave no verdict" and loaded nothing: the classifier
refused a ThryX call the panel made on its own. The panel tries such a call
once more, then says so. `/thryx-tasks permissions` prints the permission
rules for the panel's read tools, one per tool in its `READ_TOOLS` list plus
`execute_read`, named for the server the panel reached (your `server` setting
until one answers):

```json
{
  "permissions": {
    "allow": [
      "mcp__thryx__whoami", "mcp__thryx__list_workspaces", "mcp__thryx__list_projects",
      "mcp__thryx__list_statuses", "mcp__thryx__list_cycles", "mcp__thryx__list_cycle_issues",
      "mcp__thryx__list_issues", "mcp__thryx__list_activity", "mcp__thryx__get_workload",
      "mcp__thryx__get_issue", "mcp__thryx__execute_read"
    ]
  }
}
```

Add them to `~/.claude/settings.json`, then reopen the panel. They allow
those read tools for Claude in every session too, not only for the panel.

## Settings

Set in `/config` (thryx-tasks), or in `~/.claude/settings.json` under
`pluginConfigs["thryx-tasks@ogxo"].options`:

| Field | Default | Meaning |
|---|---|---|
| `server` | `thryx` | The ThryX MCP server's name as `/mcp` lists it; tried first, then `thryx` and `claude.ai ThryX` |
| `workspace` | empty | Default workspace slug; the board picker overrides it |
| `project` | empty | Default project key; empty means the panel asks |
| `refreshMinutes` | `5` | Reload interval while the panel is open; `0` turns it off |
| `issueUrlTemplate` | empty | A ticket's web URL with `{key}`, `{workspace}` and `{project}` placeholders |
| `icons` | `emoji` | `plain` draws ASCII markers |
| `statusLine` | `on` | `off` drops the summary on the hint line under the prompt, and the reloads it makes while the panel is closed |

## What it reads

The panel only reads: the module calls ThryX through one function, `thryx()`,
which refuses any tool outside its `READ_TOOLS` list
([hooks/register.tsx:23](hooks/register.tsx), check at
[hooks/register.tsx:214](hooks/register.tsx)); that function holds the
module's only `$.mcp.call` sites ([hooks/register.tsx:223](hooks/register.tsx),
[:229](hooks/register.tsx)). The claude.ai connector lists only a core set of
tools; a listed read tool it lacks (`list_activity`, `list_cycle_issues`,
`get_workload`) goes through the connector's `execute_read` with the tool's
name, after the same check. The list is `whoami`, `list_workspaces`,
`list_projects`, `list_statuses`, `list_cycles`, `list_cycle_issues`,
`list_issues`, `list_activity`, `get_workload` and `get_issue`. ThryX itself does not hold
the panel to reads: the token it calls with can write, so this rests on the
module's code.

A refresh makes about 4 to 10 calls, plus one per started ticket whose last
change is older than the project's newest 100 activity events (40 at most).
A ticket read that way is not read again until its status changes, and the
board's statuses are read once; **refresh** (`r`, or `/thryx-tasks refresh`)
reads both again. Opening a task's card makes one more. Changing the view makes none.
ThryX allows 120 calls a minute per token.

## Limits

- **Only me** in the Sprint view matches tickets by your display name, because
  ThryX's cycle ticket list carries names, not emails. Two members with the
  same name are merged.
- **All tasks** reads each person who holds open work in the project, 100
  tickets at a time, then a priority at a time; past 500 open tickets for one
  person the list is cut and the panel says so. Done tickets show in the
  Sprint view only.
- In **All tasks**, a row names the active sprint when the ticket is in it;
  a ticket in another cycle shows no cycle.
- The active sprint is looked for among the project's newest 150 cycles.
- "Last updated" is the ticket's newest ThryX activity event; ThryX tickets
  carry no updated-at field.

## Remove

```bash
claude plugin uninstall thryx-tasks@ogxo
```

Then delete any `pluginConfigs["thryx-tasks@ogxo"]` entry from
`~/.claude/settings.json`.

## Develop

```bash
claude plugin validate plugins/thryx-tasks
claude plugin test plugins/thryx-tasks
claude --plugin-dir plugins/thryx-tasks
```

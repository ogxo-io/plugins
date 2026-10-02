# thryx

Connects your agent to your [ThryX](https://app.thryx.io) workspaces over MCP —
searching, creating, and updating issues, planning cycles, tracking
milestones, and reading or writing project documents, all against your
live workspace data.

The plugin ships the skills and `/thryx:connect`, which connects each ThryX
workspace as its own MCP server, so one install covers every company you
work with. There is no local binary or server process: every tool call is
an HTTP request to `app.thryx.io`, authenticated with your API token, which
a small command reads from your Keychain or environment when the server
connects.

## What's in it

- **`thryx`**: how the MCP tools behave, covering search before create,
  where a new ticket goes, batching, which writes need an explicit
  confirmation, and what isn't available over MCP.
- **`/thryx:connect [workspace]`**: connects a workspace; see below.
- **`run-board`**: works a project's open Todo tickets (yours, someone's, or all) in
  waves: it reads the board, plans once and asks once, claims each wave's
  tickets, works them in parallel with subagents (through ogxo-route's routing
  when that is installed), and records each result on the ticket. It stops at
  a checkpoint after a set number of tickets so a long run doesn't pile up in
  one session, and "continue the board" picks the board up again from ticket
  statuses and local branches. Ask for it with "run the board", "work my Todo
  tickets in KEY", or `/thryx:run-board`.
- **`product-management`**: how to do the PM work well once the tools
  are in hand. It covers writing tickets, PRDs, ADRs, and the project
  overview; running standups, weekly reviews, cycle planning and close,
  and post-release follow-ups; and keeping milestones and the
  client-facing macro board true. It reads the repository alongside the
  tracker, and it loads only when you ask for that kind of work.

## Install

```bash
claude plugin marketplace add ogxo-io/plugins
claude plugin install thryx@ogxo
```

## Connect your workspaces

Each ThryX workspace has its own MCP endpoint,
`https://app.thryx.io/api/v1/mcp/<workspace>`, where `<workspace>` is its
slug; the plugin connects each one as its own server, `thryx-<workspace>`.
In Claude Code:

```text
/thryx:connect ogxo
```

It adds a user-scope server whose `headersHelper` builds the
`Authorization` header each time the server connects, so `~/.claude.json`
holds that command rather than the token. Where the token comes from:

- **macOS:** your login Keychain (item `thryx-mcp`). The first time, a
  dialog with hidden input asks for the token; get one from **Account
  settings → API tokens** in the ThryX web app. One token serves every
  workspace you connect; `--own-token` gives a workspace its own, and
  `--set-token` asks again after you rotate it.
- **Elsewhere, or with `--token-var NAME`:** an environment variable,
  `THRYX_TOKEN` by default, set in your shell profile before Claude Code
  starts.

Run it once per workspace, then restart Claude Code; `/mcp` shows whether
each server connected. `--replace` swaps an existing `thryx-<workspace>`
server, for example one added with the ThryX web app's snippet, which
stores the token in plaintext in `~/.claude.json`.

Without the command, the same server by hand, with the token in
`THRYX_TOKEN`:

```bash
claude mcp add-json --scope user thryx-ogxo "$(cat <<'JSON'
{"type": "http",
 "url": "https://app.thryx.io/api/v1/mcp/ogxo",
 "headersHelper": "printf '{\"Authorization\": \"Bearer %s\"}' \"$THRYX_TOKEN\""}
JSON
)"
```

Claude Code passes `TOKEN` variables to the helper for user- and
local-scope servers but removes them for servers in a project's
`.mcp.json`, so add these at user scope.

For Codex, the token comes from the environment:

```bash
codex mcp add thryx-ogxo --url https://app.thryx.io/api/v1/mcp/ogxo --bearer-token-env-var THRYX_TOKEN
```

**Never put a literal token in a committed `.mcp.json`.**

### Which workspace a repository uses

With several workspaces connected, the `thryx` skill works out which one
the current repository belongs to before it writes anything. Say so once in
the repository's `CLAUDE.md` (or `AGENTS.md`):

```markdown
ThryX workspace: ogxo
```

Without that line, the skill goes by a ticket key found in only one
workspace, and otherwise asks.

## What's not available over MCP

Some of the ThryX server's tools are withheld from the MCP surface:
`web_search`, `fetch_url`, `load_tools`, `split_epic`, `propose_actions`,
`list_notes`, `write_note`, and `look_at_attachment`.
`suggest_duplicates` and `semantic_search_issues` appear only when the
workspace has semantic search configured. Trust the list your client shows you.

That is less limiting than it looks. `load_tools` is unnecessary — MCP
lists the catalog up front instead of in groups. `propose_actions` is
the web agent's staging step; over MCP the plugin's skill has the agent
confirm in conversation before it writes instead. Splitting an epic has no
single tool; the skill walks it through the underlying calls and puts the
grouping to you for approval first, which is the judgement the server
withheld the tool to keep. Only
`web_search`, `fetch_url`, the private-note tools, and `look_at_attachment`
genuinely need the web app — private notes never cross an API token, because the notes
endpoint requires a signed-in session and an MCP credential is a separate
token type, and `look_at_attachment` reads files in a web-agent
conversation, of which there is none over MCP. Putting files on a ticket
does work over MCP: `create_issue`, `create_issues`, and `attach_to_issue`
take the file bytes inline.

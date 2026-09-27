# thryx

Connects your agent to a [ThryX](https://app.thryx.io) workspace over MCP —
searching, creating, and updating issues, planning cycles, tracking
milestones, and reading or writing project documents, all against your
live workspace data.

This plugin talks to a **hosted service**: there is no local binary, no
local process, and no local state. Every tool call is an HTTP request to
`app.thryx.io`, authenticated with your personal API token.

## Skills

- **`thryx`**: how the MCP tools behave, covering search before create,
  where a new ticket goes, batching, which writes need an explicit
  confirmation, and what isn't available over MCP.
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

## Configuration

Set these environment variables before starting Claude Code:

| Variable          | Value                                                        |
| ----------------- | ------------------------------------------------------------ |
| `THRYX_WORKSPACE` | Your workspace slug — the last path segment of your ThryX MCP URL |
| `THRYX_TOKEN`     | A personal API token                                          |

Get a token from **Account settings → API tokens** in the ThryX web app,
which also offers a pasteable client snippet.

**Keep the token in your environment, never in a committed `.mcp.json`.**
This plugin's own `.mcp.json` only ever contains the `${THRYX_TOKEN}`
placeholder — do not replace it with a literal token and commit that.

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

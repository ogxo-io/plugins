# thryx

Connects your agent to a [Thryx](https://app.thryx.io) workspace over MCP —
searching, creating, and updating issues, planning cycles, tracking
milestones, and reading or writing project documents, all against your
live workspace data.

This plugin talks to a **hosted service**: there is no local binary, no
local process, and no local state. Every tool call is an HTTP request to
`app.thryx.io`, authenticated with your personal API token.

## Install

```bash
claude plugin marketplace add ogxo-io/plugins
claude plugin install thryx@ogxo
```

## Configuration

Set these environment variables before starting Claude Code:

| Variable          | Value                                                        |
| ----------------- | ------------------------------------------------------------ |
| `THRYX_WORKSPACE` | Your workspace slug — the last path segment of your Thryx MCP URL |
| `THRYX_TOKEN`     | A personal API token                                          |

Get a token from **Account settings → API tokens** in the Thryx web app,
which also offers a pasteable client snippet.

**Keep the token in your environment, never in a committed `.mcp.json`.**
This plugin's own `.mcp.json` only ever contains the `${THRYX_TOKEN}`
placeholder — do not replace it with a literal token and commit that.

## What's not available over MCP

Some of the Thryx server's tools are withheld from the MCP surface:
`web_search`, `fetch_url`, `load_tools`, `split_epic`, `propose_actions`,
`list_notes`, `write_note`, `attach_to_issue`, and `look_at_attachment`.
`suggest_duplicates` is not listed over MCP either, and
`semantic_search_issues` appears only when the workspace has semantic
search configured. Trust the list your client shows you.

That is less limiting than it looks. `load_tools` is unnecessary — MCP
lists the catalog up front instead of in groups. `propose_actions` is
the web agent's staging step; over MCP the plugin's skill has the agent
confirm in conversation before it writes instead. Splitting an epic has no
single tool; the skill walks it through the underlying calls and puts the
grouping to you for approval first, which is the judgement the server
withheld the tool to keep. Only
`web_search`, `fetch_url`, the private-note tools, and the attachment tools
genuinely need the web app — private notes never cross an API token, because the notes
endpoint requires a signed-in session and an MCP credential is a separate
token type, and attachments belong to a web-agent conversation, of which
there is none over MCP.

# thryx

Connects your agent to your [ThryX](https://app.thryx.io) workspaces over MCP —
searching, creating, and updating issues, planning cycles, keeping the client-facing Roadmap
current, and reading or writing project documents, all against your
live workspace data.

The plugin ships six skills for Claude Code and Codex, including `connect`,
`replan`, and `release`. Connect ThryX once; one MCP server, `thryx`,
reaches every workspace you belong to, so one install covers every company
you work with. Every tool call is an HTTP request to `app.thryx.io`,
authenticated with your ThryX token. Claude Code
uses a header helper to read the token from your Keychain or environment;
Codex uses `http_headers_helper` for the Keychain and its bearer-token
environment variable setting for environment tokens.

## What's in it

- **`thryx`**: how the MCP tools behave, covering search before create,
  where a new ticket goes, working a ticket a person handed to the agent,
  batching, which writes need an explicit confirmation, and what isn't
  available over MCP.
- **`connect`**: connects ThryX in either client; in Claude Code,
  `/thryx:connect` runs the same workflow. See below.
- **`replan`**: proposes a cycle replan from every open ticket. In Codex,
  ask to replan the project or select the replan skill; in Claude Code,
  `/thryx:replan [KEY]` runs the same workflow. Tracker writes wait for
  your approval.
- **`release`**: prepares a release from its git tag: reconciles the tag
  with the tracker, assigns the release's tickets, writes its notes and
  promises, then asks before shipping and checks what shipped. In Codex, ask
  to prepare the release; in Claude Code, `/thryx:release [KEY] [version]`.
- **`run-board`**: works a project's open Todo tickets (yours, someone's, or all) in
  waves: it reads the board, plans once and asks once, claims each wave's
  tickets, works them with the host's available subagents (through ogxo-route
  when its workers are available, sequentially when subagents are unavailable), and records each result on the ticket. It stops at
  a checkpoint after a set number of tickets so a long run doesn't pile up in
  one session, and "continue the board" picks the board up again from ticket
  statuses and local branches. Ask for it with "run the board", "work my Todo
  tickets in KEY", or `/thryx:run-board`.
- **`product-management`**: how to do the PM work well once the tools
  are in hand. It covers writing tickets, PRDs, ADRs, and the project
  overview; running standups, weekly reviews, cycle planning and close, a replan
  of every open ticket across the cycles (`/thryx:replan [KEY]`),
  and post-release follow-ups; and keeping the client-facing
  Roadmap (releases, promises with their criteria, and outcomes) true. It reads the repository alongside the
  tracker, and it loads only when you ask for that kind of work.

## Install

### Claude Code

```bash
claude plugin marketplace add ogxo-io/plugins
claude plugin install thryx@ogxo
```

### Codex

```bash
codex plugin marketplace add ogxo-io/plugins
codex plugin add thryx@ogxo
```

For a local checkout, use its absolute path instead of `ogxo-io/plugins`.
After editing the checkout, refresh and reinstall before starting a new session:

```bash
codex plugin marketplace upgrade ogxo
codex plugin add thryx@ogxo
```

Codex discovers all six workflows under `skills/`; use its skill picker or
ask in plain language, for example "connect ThryX" or
"replan project THRY through the December promise". The Claude slash
commands remain wrappers around those shared skills.

## Connect ThryX

ThryX has one MCP endpoint, `https://app.thryx.io/api/v1/mcp`; the plugin
connects it as the server `thryx`, and the agent names the workspace on
each call. The per-workspace endpoint `/api/v1/mcp/<workspace>` still works
and is the pinned form, for a token minted for one workspace or for an
existing setup. In Claude Code:

```text
/thryx:connect
```

It adds a user-scope server whose `headersHelper` builds the
`Authorization` header each time the server connects, so `~/.claude.json`
holds that command rather than the token. Where the token comes from:

- **macOS:** your login Keychain (item `thryx-mcp`). The first time, a
  dialog with hidden input asks for the token; mint one in the ThryX web
  app under **Account settings → Your agent → + New token**, choosing **Any
  workspace I belong to** (a token minted for one workspace reaches only
  that one). `--set-token` asks again after you rotate it.
- **Elsewhere, or with `--token-var NAME`:** an environment variable,
  `THRYX_TOKEN` by default, set in your shell profile before Claude Code
  starts.

Run it once, then restart Claude Code; `/mcp` shows whether the server
connected. Claude Code connects with `?tools=all`, so it lists every tool.
`--replace` swaps an existing `thryx` server, for example one added with
the ThryX web app's snippet, which stores the token in plaintext in
`~/.claude.json`. Earlier versions of the plugin added one
`thryx-<workspace>` server per workspace; the command lists the entries
named `thryx-<workspace>` that point at
`https://app.thryx.io/api/v1/mcp/<workspace>`, and `--clean-old` removes
them (at user scope) once `thryx` is in place. Check with `list_workspaces`
that `thryx` reaches those workspaces first: it does only if its token was
minted for any workspace. Keychain items left by the old `--own-token`
(`thryx-mcp`, account `<workspace>`) stay; delete them in Keychain Access
if you no longer need them.

Without the command, the same server by hand, with the token in
`THRYX_TOKEN`:

```bash
claude mcp add-json --scope user thryx "$(cat <<'JSON'
{"type": "http",
 "url": "https://app.thryx.io/api/v1/mcp?tools=all",
 "headersHelper": "printf '{\"Authorization\": \"Bearer %s\"}' \"$THRYX_TOKEN\""}
JSON
)"
```

Claude Code passes `TOKEN` variables to the helper for user- and
local-scope servers but removes them for servers in a project's
`.mcp.json`, so add these at user scope.

### Letting handed work run

When you hand a ticket to your agent, it claims the ticket, reports
progress, finishes a review or an investigation with what it found, and
gives the ticket back if it can't finish. Claude Code asks before
each of those writes in the default mode, and auto mode may hold one it
doesn't see you ask for in the session. These five tools act for the
token of the call, on a hand-off you made to that same token. To let them
run without a prompt, add them with `/permissions`, or in
`~/.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "mcp__thryx__list_handoffs",
      "mcp__thryx__claim_handoff",
      "mcp__thryx__report_handoff_progress",
      "mcp__thryx__finish_handoff",
      "mcp__thryx__release_handoff"
    ]
  }
}
```

`mcp__thryx__*` or `mcp__thryx__execute_write` would allow every write
the token can make.

### Codex connection

Ask Codex to "connect ThryX". The `connect` skill runs:

```bash
bash "<plugin-path>/scripts/connect.sh" --client codex
```

On macOS, it configures `http_headers_helper` to read your login Keychain
(item `thryx-mcp`, account `shared`), so the desktop app does not need to
inherit a shell token variable. Python 3 is required. A hidden-input dialog
asks for the token if it is missing; the token is shared with Claude Code's
Keychain flow. The generated helper uses absolute executable paths and
prints JSON headers without storing the token in `config.toml`. Codex
gets the default list, a core of twenty tools; the agent finds the rest
with `discover_tools`.

Use `--set-token` to enter a replacement token and `--clean-old` to
remove old `thryx-<workspace>` entries. Use `--replace` to migrate an
existing environment-based entry to Keychain authentication:

```bash
bash "<plugin-path>/scripts/connect.sh" --client codex --replace
```

Saved OAuth credentials take precedence over helper headers. If you
previously logged in with OAuth, run `codex mcp logout thryx` when
switching to the API-token helper. See [OpenAI's configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference)
for `http_headers_helper` and authentication precedence.

Elsewhere, or with `--token-var NAME`, it uses an environment variable.
For example:

```bash
codex mcp add thryx --url https://app.thryx.io/api/v1/mcp --bearer-token-env-var THRYX_TOKEN
```

Set the variable outside the chat in the environment of the process that
starts Codex. A shell export applies to clients launched from that shell;
it does not set the variable for a desktop app launched elsewhere.
Use `--token-var NAME` for a different variable. `--set-token` requires
Keychain mode; environment mode does not require `security`, `osascript`,
or Python (listing old entries uses `jq` when it is installed).

Start a new session and check `/mcp`. Registration configures the server;
a successful tool call verifies authentication.

See [OpenAI's plugin packaging guidance](https://developers.openai.com/plugins/build/plugins)
for local marketplaces and plugin skill discovery.

**Never put a literal token in a committed `.mcp.json`.**

### claude.ai and ChatGPT

Connector clients don't use `/thryx:connect` or a token. Add
`https://app.thryx.io/api/v1/mcp` as a custom connector and sign in; the
consent screen asks which workspaces it can reach and whether it gets read
only or full access. Revoke or narrow the grant later under **Account
settings → Your agent → Connected apps**. ThryX's MCP documentation
covers connector setup in "Claude.ai, ChatGPT and other connector
clients".

### Which workspace a repository uses

When the connection reaches several workspaces, the `thryx` skill works
out which one the current repository belongs to before it writes anything,
and passes it as `workspace` on each call. Say so once in
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

That is less limiting than it looks. `load_tools` is unnecessary: a
connection lists a core of twenty tools, `discover_tools` finds the rest
by plain-language query or group with their full schemas, and
`execute_read`, `execute_write` and `execute_irreversible` run what it
finds. Claude Code, which defers tool schemas itself, is configured with
`?tools=all` by `/thryx:connect` and lists every tool natively.
`propose_actions` is
the web agent's staging step; over MCP the plugin's skill has the agent
confirm in conversation before it writes instead. Splitting an epic has no
single tool; the skill walks it through the underlying calls and puts the
grouping to you for approval first, which is the judgement the server
withheld the tool to keep. Only
`web_search`, `fetch_url`, the private-note tools, and `look_at_attachment`
genuinely need the web app — private notes never cross an MCP connection,
because every notes tool is withheld over MCP and the notes endpoint
requires a signed-in session, which an MCP credential (personal token or
OAuth grant) is not, and `look_at_attachment` reads files in a web-agent
conversation, of which there is none over MCP. Putting files on a ticket
does work over MCP: `create_issue`, `create_issues`, and `attach_to_issue`
take the file bytes inline.

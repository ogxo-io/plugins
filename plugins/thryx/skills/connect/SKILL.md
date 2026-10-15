---
name: connect
description: Connect or reconnect ThryX to Codex or Claude Code over MCP, configure a token variable, rotate its Keychain token, or remove the old per-workspace entries. Use when ThryX tools are missing or the user asks to set up a ThryX connection.
---

# Connect ThryX

ThryX is one MCP server, `thryx`, at `https://app.thryx.io/api/v1/mcp`. It
needs no workspace name; the agent names one on each call. The token must
be minted in the ThryX web app under **Account settings → Your agent →
+ New token**, choosing **Any workspace I belong to**. A token minted for
one workspace reaches only that workspace on this address; tell the user
to expect other workspaces to answer that they are not reachable.

Validate a custom token variable against `^[A-Za-z_][A-Za-z0-9_]*$` before
inserting it into a shell command, and quote it.

In Claude Code the script is `${CLAUDE_PLUGIN_ROOT}/scripts/connect.sh`;
elsewhere, resolve `../../scripts/connect.sh` relative to this SKILL.md's
directory. Use its absolute path in the commands below. Select the client from
the current host, not from which executables happen to be installed; ask
only if the target client is ambiguous. Show the script's output unchanged.

## Codex

Run the bundled script with the explicit client:

```bash
bash "<absolute-plugin-path>/scripts/connect.sh" --client codex
```

On macOS, the script uses `http_headers_helper` to read the token from
the login Keychain (item `thryx-mcp`, account `shared`). No shell token
variable is needed. Python 3 is required; the generated helper stores
absolute executable paths so it also works in the desktop app. When no
token is stored, a hidden-input dialog asks for one; tell the user to look
for the dialog. The same Keychain token can be shared with Claude Code.
Codex gets the default list, a core of twenty tools; the agent finds the
rest with `discover_tools`.

Flags: `--set-token` opens the dialog again to rotate the token;
`--replace` updates an existing `thryx` entry. Existing entries are kept
unless replacement was requested; use `--replace` to migrate an existing
environment-based entry to the Keychain helper. Saved OAuth credentials
also take precedence over the helper; if previously logged in, run
`codex mcp logout thryx` when switching to token auth.

Elsewhere, or with `--token-var NAME`, the script registers a bearer-token
environment variable (`THRYX_TOKEN` by default) without reading it.
Tell the user to set it outside the chat in the environment of the process
that starts Codex. A terminal export only affects clients launched from
that terminal; editing a shell profile does not configure an already
running app. `--set-token` requires Keychain mode.

Start a new Codex session and check `/mcp`. Registration configures the
server but does not verify authentication; a successful tool call does.

## Claude Code

Run the same script with its Claude mode:

```bash
bash "<absolute-plugin-path>/scripts/connect.sh" --client claude
```

On macOS, the script opens a hidden-input dialog when no token is stored
and saves it in the login Keychain; tell the user to look for the dialog.
Elsewhere, or with `--token-var NAME`, it uses an environment variable.
Flags: `--set-token` asks again after rotation; `--token-var NAME` chooses
an environment variable; `--replace` replaces the existing server. Claude
Code connects with `?tools=all`, which lists every tool.
Restart Claude Code after adding a server and check `/mcp`.

### Letting handed work run

Claude Code asks before each MCP write in the default mode, and auto mode
may hold a write it doesn't see the user ask for, so an agent working a
ticket handed to it can stop at the claim. The agent side of a hand-off is
narrow: `claim_handoff`, `report_handoff_progress`, `finish_handoff`, and
`release_handoff` act for the token of the call, on a hand-off the person
made to that same token. After connecting, offer the user these allow rules:

```text
mcp__thryx__list_handoffs
mcp__thryx__claim_handoff
mcp__thryx__report_handoff_progress
mcp__thryx__finish_handoff
mcp__thryx__release_handoff
```

The user adds them with `/permissions` or under `permissions.allow` in
`~/.claude/settings.json`; don't edit their permission settings yourself.
Don't suggest `mcp__thryx__*` or `mcp__thryx__execute_write`: those allow
every write the token can make.

## Old per-workspace entries

Earlier versions added one server per workspace, `thryx-<workspace>`. Once
`thryx` is configured, the script lists the entries named
`thryx-<workspace>` whose URL is `https://app.thryx.io/api/v1/mcp/<workspace>`.
`--clean-old` removes those, in either client (in Claude Code, at user
scope only), and only after `thryx` is in place. Ask the user first, and
have them confirm after a restart that `list_workspaces` on `thryx` shows
those workspaces: it does only if the token was minted for any workspace.

## Connector clients

claude.ai and ChatGPT do not use this skill. Add
`https://app.thryx.io/api/v1/mcp` as a custom connector and sign in; the
consent screen asks which workspaces it can reach and whether it gets read
only or full access. Revoke or narrow it under **Account settings → Your
agent → Connected apps**.

## Credential handling

Do not ask for a token in the conversation or read, print, or echo a token
or its variable. Do not put a literal token in a command, a config file,
a ticket, or a repository file. Leave token entry to the user outside the
chat. Do not call ThryX tools until the connection is available.

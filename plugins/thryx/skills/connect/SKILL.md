---
name: connect
description: Connect or reconnect a ThryX workspace to Codex or Claude Code over MCP, configure a workspace token variable, or rotate its Keychain token. Use when ThryX tools are missing or the user asks to set up a workspace connection.
---

# Connect a ThryX workspace

Use the workspace slug the user gives, or the repository's `ThryX workspace:
<slug>` line in `AGENTS.md` or `CLAUDE.md`. If none is available, ask for the
slug: it is the last part of `https://app.thryx.io/api/v1/mcp/<workspace>`,
shown under **Account settings → API tokens** in the ThryX web app.
Validate it against `^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$` before inserting it
into a shell command. Validate a custom token variable against
`^[A-Za-z_][A-Za-z0-9_]*$`. Quote both arguments.

In Claude Code the script is `${CLAUDE_PLUGIN_ROOT}/scripts/connect.sh`;
elsewhere, resolve `../../scripts/connect.sh` relative to this SKILL.md's
directory. Use its absolute path in the commands below. Select the client from
the current host, not from which executables happen to be installed; ask
only if the target client is ambiguous. Show the script's output unchanged.

## Codex

Run the bundled script with the explicit client:

```bash
bash "<absolute-plugin-path>/scripts/connect.sh" "<workspace>" --client codex
```

On macOS, the script uses `http_headers_helper` to read the token from
the login Keychain (item `thryx-mcp`, account `shared`). No shell token
variable is needed. Python 3 is required; the generated helper stores
absolute executable paths so it also works in the desktop app. When no
token is stored, a hidden-input dialog asks for one; tell the user to look
for the dialog. The same Keychain token can be shared with Claude Code.

Flags: `--own-token` uses this workspace's Keychain account;
`--set-token` opens the dialog again to rotate the token; `--replace`
updates an existing `thryx-<workspace>` entry. Existing entries are kept
unless replacement was requested; use `--replace` to migrate an existing
environment-based entry to the Keychain helper. Saved OAuth credentials
also take precedence over the helper; if previously logged in, run
`codex mcp logout "thryx-<workspace>"` when switching to API-token auth.

Elsewhere, or with `--token-var NAME`, the script registers a bearer-token
environment variable (`THRYX_TOKEN` by default) without reading it.
Tell the user to set it outside the chat in the environment of the process
that starts Codex. A terminal export only affects clients launched from
that terminal; editing a shell profile does not configure an already
running app. `--own-token` and `--set-token` require Keychain mode.

Start a new Codex session and check `/mcp`. Registration configures the
server but does not verify authentication; a successful tool call does.

## Claude Code

Run the same script with its Claude mode:

```bash
bash "<absolute-plugin-path>/scripts/connect.sh" "<workspace>" --client claude
```

On macOS, the script opens a hidden-input dialog when no token is stored
and saves it in the login Keychain; tell the user to look for the dialog.
Elsewhere, or with `--token-var NAME`, it uses an environment variable.
Flags: `--own-token` gives this workspace its own Keychain token;
`--set-token` asks again after rotation; `--token-var NAME` chooses an
environment variable; `--replace` replaces the existing server.
Restart Claude Code after adding a server and check `/mcp`.

## Credential handling

Do not ask for a token in the conversation or read, print, or echo a token
or its variable. Do not put a literal token in a command, a config file,
a ticket, or a repository file. Leave token entry to the user outside the
chat. Do not call ThryX tools until the workspace connection is available.

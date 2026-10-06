---
name: connect
description: Connect or reconnect a ThryX workspace to Codex or Claude Code over MCP, configure a workspace token variable, or rotate the Claude Keychain token. Use when ThryX tools are missing or the user asks to set up a workspace connection.
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

Optional flags: `--token-var NAME` chooses a variable instead of
`THRYX_TOKEN`; `--replace` updates an existing `thryx-<workspace>` entry.
An existing entry is kept unless replacement was requested. The script
registers the HTTP endpoint and variable name; Codex reads the token from
its environment when connecting. Registration does not verify authentication.

Tell the user to set the variable outside the chat before starting Codex,
then start a new session and check `/mcp`. For the desktop app, the variable
must be available to the app process; a terminal export affects processes
launched from that terminal. Do not claim that editing a shell profile
sets a variable for an already running app.

Codex does not use this script's Claude Keychain flow. For separate
workspace tokens, use separate variable names. For rotation, change the
variable's value outside the chat and restart the client; `--own-token`
and `--set-token` are Claude-only flags.

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

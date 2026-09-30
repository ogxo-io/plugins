---
description: Connect a ThryX workspace as an MCP server; on macOS a dialog stores the token in your Keychain
argument-hint: "[workspace] [--own-token] [--set-token] [--token-var NAME] [--replace]"
allowed-tools: Bash(bash *connect.sh*)
---

If no workspace was given in `$ARGUMENTS`, ask for it first: it is the last part of the workspace's MCP URL (`https://app.thryx.io/api/v1/mcp/<workspace>`), shown with the client snippet under **Account settings → API tokens** in the ThryX web app. Then run exactly this, with the workspace first and any flags after it, and show its output unchanged:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/connect.sh" <workspace> <flags>
```

On macOS the script opens a dialog for the token when none is stored yet, and keeps it in the login Keychain; tell the user to look for that dialog. Elsewhere, or with `--token-var`, the token comes from an environment variable, and the output says how to set it.

Never ask the user to paste their token into the conversation, and never print, read, or echo a token or token variable yourself.

Flags: `--own-token` gives this workspace its own token instead of the shared one; `--set-token` asks for the token again (after rotating it); `--token-var NAME` reads the token from that environment variable instead of the Keychain; `--replace` replaces an existing `thryx-<workspace>` server, for example one added with the token in plaintext.

---
description: Connect a ThryX workspace as an MCP server; on macOS a dialog stores the token in your Keychain
argument-hint: "[workspace] [--own-token] [--set-token] [--token-var NAME] [--replace]"
allowed-tools: Read, Bash(bash *connect.sh*)
---

Read `${CLAUDE_PLUGIN_ROOT}/skills/connect/SKILL.md` and follow its Claude
Code section. The host is Claude Code, so pass `--client claude`, and the
script is `${CLAUDE_PLUGIN_ROOT}/scripts/connect.sh`.
Treat `$ARGUMENTS` as the user's workspace and connection flags.

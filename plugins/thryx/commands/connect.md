---
description: Connect ThryX as one MCP server that reaches every workspace your token does; on macOS a dialog stores the token in your Keychain
argument-hint: "[--set-token] [--token-var NAME] [--replace] [--clean-old]"
allowed-tools: Read, Bash(bash *connect.sh*)
---

Read `${CLAUDE_PLUGIN_ROOT}/skills/connect/SKILL.md` and follow its Claude
Code section. The host is Claude Code, so pass `--client claude`, and the
script is `${CLAUDE_PLUGIN_ROOT}/scripts/connect.sh`.
Treat `$ARGUMENTS` as connection flags.

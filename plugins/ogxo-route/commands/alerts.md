---
description: Turn on or off a desktop notification (and optional push) when Claude Code waits on a permission prompt, send a test alert, or show status
argument-hint: "[on [https-push-url] | off | test]"
allowed-tools: Bash(CLAUDE_PLUGIN_DATA=*)
---

Run exactly this and show its output:

```bash
CLAUDE_PLUGIN_DATA="${CLAUDE_PLUGIN_DATA}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/alerts.sh" $ARGUMENTS
```

Alerts are off until turned on. The desktop notification uses `terminal-notifier` on macOS when installed (clicking it brings the app running Claude Code forward), otherwise, or when macOS has not allowed its notifications, `osascript` (clicking it opens Script Editor), and `notify-send` on Linux. A push URL receives a fixed message only, not the prompt's text.

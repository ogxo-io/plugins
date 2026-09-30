---
description: Open a live HTML board of this session's agents and tool calls, list every board, turn it off, or show status
argument-hint: "[on|off|status|hub|demo]"
allowed-tools: Bash(CLAUDE_PLUGIN_DATA=*), Bash(open:*), Bash(xdg-open:*)
---

Run exactly this and show its output unchanged:

```bash
CLAUDE_PLUGIN_DATA="${CLAUDE_PLUGIN_DATA}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/dash.sh" $ARGUMENTS
```

For `on` (the default, when no argument is given), `hub`, and `demo`, then open the URL on the printed `Open:` line: `open "<url>"` on macOS, `xdg-open "<url>"` on Linux. The user asked for the page by running this command. If opening fails, show the URL so they can paste it into a browser.

The board is a local file that updates live. Recording stops when the session ends or with `/ogxo-route:dashboard off`, and a board whose Claude Code process has exited is marked ended by the next dashboard command; the board files stay for replay. `hub` lists every session's board (repo, branch, working or idle, agents running) with a link to each; each board links back to it. `demo` replays a sample session and needs no recording.

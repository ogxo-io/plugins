---
description: Open a live HTML board of this session's agents and tool calls, list every board, serve them over HTTP on this machine, turn it off, or show status
argument-hint: "[on|off|status|hub|demo|serve [port|stop]]"
allowed-tools: Bash(CLAUDE_PLUGIN_DATA=*), Bash(open:*), Bash(xdg-open:*)
---

Run exactly this and show its output unchanged:

```bash
CLAUDE_PLUGIN_DATA="${CLAUDE_PLUGIN_DATA}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/dash.sh" $ARGUMENTS
```

For `on` (the default, when no argument is given), `hub`, `demo`, and `serve`, then open the URL on the printed `Open:` line: `open "<url>"` on macOS, `xdg-open "<url>"` on Linux. The user asked for the page by running this command. If opening fails, show the URL so they can paste it into a browser.

The board is a local file that updates live, in `~/.ogxo/route/boards/` (or `OGXO_ROUTE_BOARDS`), shared by Claude Code and Grok Build sessions. Recording stops when the session ends or with `/ogxo-route:dashboard off`, and a board whose Claude Code process has exited is marked ended by the next dashboard command; resuming that session (`claude --resume`) turns its board back on unless it was turned off; the board files stay for replay. `hub` lists every session's board (repo, branch, working or idle, agents running) with a link to each; each board links back to it. `demo` replays a sample session and needs no recording. `serve` starts a small HTTP server for the boards (python3, bound to 127.0.0.1, port 8765 or the next free one) that keeps running until `serve stop`; the output says how to reach it from another device with Tailscale or SSH. Plan usage (5-hour and weekly windows) shows on the boards when the ogxo-statusline status line is installed.

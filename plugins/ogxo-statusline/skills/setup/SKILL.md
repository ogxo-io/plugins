---
name: setup
description: Install or update the ogxo status line: copy its script to ~/.claude/ogxo-statusline.sh and point the statusLine setting in ~/.claude/settings.json at it. Also removes it when asked.
disable-model-invocation: true
argument-hint: "[--uninstall]"
---

# Set up the ogxo status line

A plugin can't set the status line itself: `statusLine` lives in the user's own settings, and `${CLAUDE_PLUGIN_ROOT}` doesn't expand there. The plugin's install path also changes on every update. So setup copies the script to a stable path and points the setting at that copy. Re-running setup after a plugin update is how the copy gets the new version.

The script source is `${CLAUDE_PLUGIN_ROOT}/scripts/ogxo-statusline.sh`. If that variable wasn't substituted, use the base directory printed when this skill loaded and go two levels up to the plugin root.

## Install or update

1. Check `jq` is on `PATH`. The script prints only `ogxo` without it, so if it's missing, say how to install it (`brew install jq`, `apt install jq`) and continue; the user can install it afterwards.
2. Copy the script to `~/.claude/ogxo-statusline.sh` and make it executable. Options belong in the settings command, not the script, so a plain update just overwrites the copy. If the existing file differs from every released version in ways that look like hand edits (for example changed colors), show the diff and ask before overwriting. If it's a symlink, leave it: someone is running it from a checkout.
3. Read `~/.claude/settings.json` (treat a missing file as `{}`).
   - If `statusLine` already points at `~/.claude/ogxo-statusline.sh`, keep its command as it is, including any options after the path; the setting needs no change.
   - If it points at something else, show the current value and ask before replacing it.
4. After the user agrees, back up the file to `~/.claude/settings.json.bak`, then set only the `statusLine` key and keep every other key as it is, for example:

   ```bash
   f=~/.claude/settings.json; tmp=$(mktemp)
   { [ -f "$f" ] && cat "$f" || echo '{}'; } | jq '.statusLine = {"type": "command", "command": "~/.claude/ogxo-statusline.sh", "padding": 0, "refreshInterval": 60}' >"$tmp" && mv "$tmp" "$f"
   ```

   `refreshInterval` keeps the session timer, cache countdown, and reset times current while the session is idle. If the user asked for options (see the README), append them to the command, for example `"~/.claude/ogxo-statusline.sh --no-git --cost=always"`.
5. Tell the user the status line appears on the next update (a new message or the next refresh), and that re-running `/ogxo-statusline:setup` after a plugin update refreshes the copy.

## Uninstall (`--uninstall`)

Remove the `statusLine` key from `~/.claude/settings.json` only if it points at `~/.claude/ogxo-statusline.sh` (back up the file first), then delete `~/.claude/ogxo-statusline.sh`. If `statusLine` points at something else, leave it and say so.

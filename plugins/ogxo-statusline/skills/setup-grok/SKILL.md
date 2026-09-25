---
name: setup-grok
description: Install or update the ogxo status line for Grok Build. Copies its script into the Grok home and sets [ui.status_line] in that home's config.toml. Also removes it when asked.
disable-model-invocation: true
argument-hint: "[--uninstall]"
---

# Set up the ogxo status line on Grok Build

Grok reads `[ui.status_line]` from the user config file (`$GROK_HOME/config.toml` when `GROK_HOME` is set, otherwise `~/.grok/config.toml`). A repository `.grok/config.toml` does not supply this table. The plugin install path changes on every update, so setup copies the script to a stable path next to that config and points `command` at the copy.

Resolve the plugin root and the Grok home once, and use both in every step below:

```bash
root="${CLAUDE_PLUGIN_ROOT:-${GROK_PLUGIN_ROOT:-}}"
home="${GROK_HOME:-$HOME/.grok}"
```

If neither plugin-root variable is set, set `root` to the base directory printed when this skill loaded, two levels up. The script source is `"$root/scripts/ogxo-statusline-grok.sh"`, and the config editor is `"$root/scripts/configure-grok.py"`, which rewrites only the `[ui.status_line]` table and runs with `python3`. Check `"$root/scripts/configure-grok.py"` exists before step 3; if it doesn't, the root is wrong, so stop and say so. The script copy is `"$home/ogxo-statusline.sh"`. If `config.toml` there is a symlink, the editor follows it and edits the target. Do not edit a repository `.grok/config.toml`.

## Install or update

1. Check `jq` is on `PATH`. The script prints only `ogxo` without it, so if it's missing, say how to install it (`brew install jq`, `apt install jq`) and continue; the user can install it afterwards. `python3` is required to edit `config.toml`. If it is missing, stop before writing config.
2. Copy the script to `"$home/ogxo-statusline.sh"` and make it executable. Options belong in the config command, not the script, so a plain update overwrites the copy. If the existing file differs from the plugin script in ways that look like hand edits (for example changed colors), show the diff and ask before overwriting. If it's a symlink, leave it and say so.
3. Run `python3 "$root/scripts/configure-grok.py" check`. Read `status`, `command_expected`, and `command`.
   - `status=match` and `command` is already the line you would write (the expected path, plus any options the user asked for): leave `config.toml` alone.
   - `status=absent`: write the table. Invoking this skill is the request to install.
   - `status=other`: show the printed table and ask before replacing it.
   - `status=inline` or `status=ambiguous`: stop. Show the printed lines. Do not edit the file.
   - `status=refused` (from install or uninstall): the script did not write, because the file isn't valid TOML or the edit would not have produced the intended table. Show the `reason` line and stop.
4. When writing, run `python3 "$root/scripts/configure-grok.py" install`. The script copies the current file to `config.toml.bak` beside the file it edits, then writes:

   ```toml
   [ui.status_line]
   type = "command"
   command = "~/.grok/ogxo-statusline.sh"
   padding = 0
   refresh_interval = 60
   ```

   When the home is not `~/.grok`, `command_expected` is an absolute path; write that path. To include options, pass `--command` with the script path and the options, for example `--command "~/.grok/ogxo-statusline.sh --no-git --cost=never"`. `refresh_interval` re-runs the script while the session is idle, so the git segment can update. Numbers taken from Grok's payload stay as of the last session update on those timer runs.
5. If this run wrote `[ui.status_line]`, tell the user to restart Grok. Grok reads that table at startup. A script-only update applies on the next run. Re-running `/ogxo-statusline:setup-grok` after a plugin update refreshes the copy.

## Uninstall (`--uninstall`)

Run `python3 "$root/scripts/configure-grok.py" uninstall`.

- `status=removed` or `status=absent`: delete `"$home/ogxo-statusline.sh"` when it is a regular file. When it is a symlink, remove the symlink only and say the target file was left in place.
- `status=other`, `status=inline`, or `status=ambiguous`: leave both the config and the script, and say what the command points at.

The editor backs up the config before it removes the table, and it removes the table only when `type` is `command` and the command's program is this script.

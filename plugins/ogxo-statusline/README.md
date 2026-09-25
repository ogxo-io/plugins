# ogxo-statusline

A status line for Claude Code and Grok Build. Each host has its own script, because the JSON on stdin and the settings file are different. Both take every value from that JSON plus local `git`. The scripts make no network calls and don't read credentials.

## Claude Code

```
Opus │ ◔ 43% (426k/1.0m) │ plugins (main*) ↑1 ~1 │ ⏱ 1h15m │ ◐ thinking effort:xhigh │ out:1k cache:91%
5h ●○○○○○ 24% ⟳10:23pm │ 7d ●●●●●○ 91% ⟳sep 29
```

- **Line 1:** model, context window use, directory with git branch (`*` when dirty, `↑`/`↓` against upstream, `~N` changed files) and worktree name, session time, thinking and effort level, output tokens, prompt-cache hit ratio, and session cost.
  - The cache segment adds `cold in 4m` during the cache's last ten minutes, and `cold` once it has expired, since the next message then re-processes the whole prompt.
  - Session cost is Claude Code's list-price estimate. By default it shows only when there's no plan usage line, which is the case for API-key users.
- **Line 2:** 5-hour and 7-day plan usage with reset times, and the spend limit when a Claude apps gateway sets one. It appears only when Claude Code sends that data (claude.ai Pro and Max, after the first response).

```bash
claude plugin marketplace add ogxo-io/plugins
claude plugin install ogxo-statusline@ogxo
```

Then run `/ogxo-statusline:setup`. Install does not set the status line: `statusLine` lives in the user's own settings, and the plugin's install path changes on every update. Setup copies the script to `~/.claude/ogxo-statusline.sh` and sets `statusLine` in `~/.claude/settings.json`, asking before it replaces an existing status line or a customized copy. Run it again after a plugin update to refresh the copy, or with `--uninstall` to remove it.

Add options to the `statusLine` command, for example `"command": "~/.claude/ogxo-statusline.sh --no-git --cost=always"`. Setup keeps them when it updates the script.

| Option | Effect |
|---|---|
| `--no-git` | Skip the git branch segment |
| `--no-usage` | Skip the plan usage line |
| `--no-cache` | Skip output tokens and prompt-cache status |
| `--cost=auto\|always\|never` | Session cost: only without plan usage (default), always, or never |
| `--basic-colors` | 16-color ANSI instead of 24-bit color |
| `--no-color` | Plain text; also used when `NO_COLOR` is set |

## Grok Build

```
Grok 4.7 │ ◔ 12% (40k/1.0m) │ plugins (main*) ↑1 ~1 │ ⏱ 1h15m │ turn 12s │ effort:high │ out:12k cache:91% │ $0.42
```

- **Model, directory, git, worktree, session time, effort.** Same segments as the Claude line. Git branch, dirty state, ahead/behind, and changed-file count come from local `git status`.
- **Context.** `used_percentage` and the parenthetical are the live window: `context_tokens` / `context_window_size`. Session totals are not added into that fraction.
- **Turn.** Elapsed time since `turn.started_at_ms`, from the local clock. The segment is absent between turns.
- **Output and cache.** `out` is the session output total. `cache` is cache-read tokens divided by session input + cache creation + cache read (`session_usage`). Grok does not send a prompt-cache hit ratio or a warm/cold flag.
- **Cost.** `cost.total_cost_usd` when Grok includes it. There is no plan-usage line, so the cost is on line 1.
- **Not shown.** Thinking on/off, and 5-hour, 7-day, and spend bars. Grok does not send those fields.

```bash
grok plugin marketplace add ogxo-io/plugins
grok plugin install ogxo-statusline --trust
```

Then run `/ogxo-statusline:setup-grok`. Grok reads `[ui.status_line]` from the user config (`$GROK_HOME/config.toml`, or `~/.grok/config.toml`). A repository `.grok/config.toml` does not supply that table. Setup copies the script to `ogxo-statusline.sh` in that home and writes the table, asking before it replaces an existing status line or a customized copy. A new table is picked up on the next launch of Grok. Run setup again after a plugin update to refresh the copy, or with `--uninstall` to remove it.

`refresh_interval` is 60 seconds, so the script also runs while the session is idle and the git segment can update. On those timer runs, numbers that come from Grok's payload stay as of the last session update.

Append options to the `command` value, for example `command = "~/.grok/ogxo-statusline.sh --no-git --cost=never"`. Setup leaves a command that already points at this script, including options, as it is.

| Option | Effect |
|---|---|
| `--no-git` | Skip the git branch segment |
| `--no-cache` | Skip session output tokens and the cache-read share |
| `--cost=auto\|always\|never` | `auto` and `always` show the cost when Grok sends one; `never` hides it |
| `--basic-colors` | 16-color ANSI instead of 24-bit color |
| `--no-color` | Plain text; also used when `NO_COLOR` is set |

## Requirements

`jq` on `PATH` (without it the status line shows only `ogxo`), and `git` for the branch segment. The Grok setup skill uses `python3` to edit `config.toml`.

Each script runs one `jq` call and one `git status` per render, with `--no-optional-locks` so it doesn't contend with other git commands.

## Customizing

Edit the color variables at the top of the installed copy (`~/.claude/ogxo-statusline.sh` or the Grok home's `ogxo-statusline.sh`). Setup shows the diff and asks before overwriting a hand-edited copy.

## Contents

- `/ogxo-statusline:setup` (Claude Code skill)
- `/ogxo-statusline:setup-grok` (Grok Build skill)
- `scripts/ogxo-statusline.sh`
- `scripts/ogxo-statusline-grok.sh`
- `scripts/configure-grok.py`

# ogxo-statusline

A two-line status line for Claude Code.

```
Opus │ ◔ 43% (426k/1.0m) │ plugins (main*) ↑1 ~1 │ ⏱ 1h15m │ ◐ thinking effort:xhigh │ out:1k cache:91%
5h ●○○○○○ 24% ⟳10:23pm │ 7d ●●●●●○ 91% ⟳sep 29
```

- **Line 1:** model, context window use, directory with git branch (`*` when dirty, `↑`/`↓` against upstream, `~N` changed files) and worktree name, session time, thinking and effort level, output tokens, prompt-cache hit ratio, and session cost.
  - The cache segment adds `cold in 4m` during the cache's last ten minutes, and `cold` once it has expired, since the next message then re-processes the whole prompt.
  - Session cost is Claude Code's list-price estimate. By default it shows only when there's no plan usage line, which is the case for API-key users.
- **Line 2:** 5-hour and 7-day plan usage with reset times, and the spend limit when a Claude apps gateway sets one. It appears only when Claude Code sends that data (claude.ai Pro and Max, after the first response).

Every value comes from the JSON Claude Code passes to the script on stdin, plus local `git`. The script makes no network calls and doesn't read credentials.

## Install

```bash
claude plugin marketplace add ogxo-io/plugins
claude plugin install ogxo-statusline@ogxo
```

Then run `/ogxo-statusline:setup`. A plugin can't set the status line itself, so setup copies the script to `~/.claude/ogxo-statusline.sh` and sets `statusLine` in `~/.claude/settings.json`, asking before it replaces an existing status line or a customized copy. Run it again after a plugin update to refresh the copy, or with `--uninstall` to remove it.

## Requirements

`jq` on `PATH` (without it the status line shows only `ogxo`), and `git` for the branch segment.

## Options

Add options to the `statusLine` command in `~/.claude/settings.json`, for example `"command": "~/.claude/ogxo-statusline.sh --no-git --cost=always"`. Setup keeps them when it updates the script.

| Option | Effect |
|---|---|
| `--no-git` | Skip the git branch segment |
| `--no-usage` | Skip the plan usage line |
| `--no-cache` | Skip output tokens and prompt-cache status |
| `--cost=auto\|always\|never` | Session cost: only without plan usage (default), always, or never |
| `--basic-colors` | 16-color ANSI instead of 24-bit color |
| `--no-color` | Plain text; also used when `NO_COLOR` is set |

The script runs one `jq` call and one `git status` per render, with `--no-optional-locks` so it doesn't contend with git commands Claude is running.

## Contents

- `/ogxo-statusline:setup` (skill)
- `scripts/ogxo-statusline.sh`

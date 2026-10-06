# ogxo-format

Format edited files or native Codex patch destinations with available prettier, gofmt, rustfmt, or black, then report trailing whitespace and YAML syntax errors. Requires jq.

## Install

```bash
claude plugin marketplace add ogxo-io/plugins
claude plugin install ogxo-format@ogxo
```

## What the hook does

One `PostToolUse` hook on `Edit|Write` runs three steps in order after each file has changed. The explicit Codex manifest exports `hooks/codex-hooks.json`; Claude Code and Grok Build use `hooks/hooks.json`. Codex hooks must be enabled and the plugin trusted in the host settings. Native `apply_patch` payloads are parsed from `tool_input.command`: every surviving Add/Update path is processed, Move uses the destination, and Delete entries are skipped (`hooks/patch-files.jq:22-36`, `hooks/format.sh:44`). Relative paths use the payload working directory; when that directory no longer exists, absolute paths are still processed and relative ones are skipped (`hooks/format.sh:14`). A path starting with `-` is passed to each tool as `./<path>` (`hooks/format.sh:17`). Shell-based edits do not trigger this formatter. That includes the heredoc `apply_patch` form (`apply_patch <<'EOF'` or `applypatch <<EOF`, optionally after `cd <dir> &&`) that Codex intercepts from `exec_command` and applies as a patch: Codex reports it to hooks as `Bash`, and this hook matches only `Edit|Write`. Formatting comes first, so the two checks read the file the formatter left behind; as separate hooks they would run in parallel and could read it mid-rewrite. Both checks report together.

On Codex, the hook command runs as a host process, outside Codex's sandbox. `npx --no-install prettier` runs the prettier that npx finds without installing one, which is the project's own when its `node_modules` has one, and prettier reads the project's config files and loads the plugins they name. gofmt, rustfmt, and black run from `PATH`.

- **Format**: rewrites the edited file with the formatter for its type — `npx --no-install prettier --write` for JS/TS/JSON/CSS/SCSS/Markdown/HTML/YAML, `gofmt -w` for Go, `rustfmt` for Rust, `black` for Python. A formatter that isn't installed is skipped. It does not check whether the project uses that formatter: black runs on any `.py` file when it is on `PATH`, and prettier runs with its defaults where the project has no prettier config. It reformats whole files, including Markdown, so pre-existing formatting drift shows up in the diff.
- **Trailing whitespace**: if the edited file has lines ending in whitespace anywhere (not only the lines just edited), sends the first five back to the host to fix. Skips `.md`/`.markdown` (two trailing spaces are a hard line break) and `.diff`/`.patch` files.
- **YAML syntax**: parses edited `.yml`/`.yaml` files with PyYAML (multi-document files and custom tags such as `!Ref` are accepted; it checks syntax only, not schema) and sends a syntax error back to the host. Skipped when `python3` or PyYAML is missing.

## Requirements

`jq` on `PATH`; the formatters and PyYAML are optional. Without `jq` the hook prints a notice and does nothing.

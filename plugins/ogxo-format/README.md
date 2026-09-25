# ogxo-format

Formatting hooks after every Edit/Write: format the changed file with prettier, gofmt, rustfmt, or black when found, whether or not the project uses that formatter; report trailing whitespace back to Claude; and check YAML syntax. Requires jq.

## Install

```bash
claude plugin marketplace add ogxo-io/plugins
claude plugin install ogxo-format@ogxo
```

## What each hook does

All three are `PostToolUse` hooks on `Edit|Write`, so they run after the file has changed.

- **auto-format**: rewrites the edited file with the formatter for its type — `npx --no-install prettier --write` for JS/TS/JSON/CSS/SCSS/Markdown/HTML/YAML, `gofmt -w` for Go, `rustfmt` for Rust, `black` for Python. A formatter that isn't installed is skipped. It does not check whether the project uses that formatter: black runs on any `.py` file when it is on `PATH`, and prettier runs with its defaults where the project has no prettier config. It reformats whole files, including Markdown, so pre-existing formatting drift shows up in the diff.
- **trailing-whitespace**: if the edited file has lines ending in whitespace anywhere (not only the lines just edited), sends the first five back to Claude to fix. Skips `.md`/`.markdown` (two trailing spaces are a hard line break) and `.diff`/`.patch` files.
- **yaml-validate**: parses edited `.yml`/`.yaml` files with PyYAML (multi-document files and custom tags such as `!Ref` are accepted; it checks syntax only, not schema) and sends a syntax error back to Claude. Skipped when `python3` or PyYAML is missing.

## Requirements

`jq` on `PATH`; the formatters and PyYAML are optional. Without `jq` each hook prints a notice and does nothing.

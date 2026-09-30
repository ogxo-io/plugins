# ogxo-guards

Safety hooks: reject a `git add` that would stage a .env, key, certificate, or credentials file (the pathspecs it names, and for broad adds what git status lists), reject Edit/Write calls on lock files and on node_modules/, vendor/, and .git/ paths, and reject single file writes over 1,048,576 characters. Pattern-based, so it does not catch everything; see the README. Requires jq.

## Install

```bash
claude plugin marketplace add ogxo-io/plugins
claude plugin install ogxo-guards@ogxo
```

## What each hook does

All three are `PreToolUse` hooks. When one matches, it exits with code 2, which makes Claude Code reject that tool call and show Claude the reason.

- **env-file-guard** (matcher `Bash`): for each `git add` or `git stage` in the command (including `git -C <dir> add`), it checks only the pathspecs given to that subcommand, not the rest of the command line, so `cp .env ../wt && git add src/a.rs` passes. A pathspec whose name is sensitive is rejected. For a broad add (`-A`, `--all`, `-u`, `.`, a directory, or a glob), it runs `git status --porcelain --untracked-files=all` on those pathspecs and rejects the add if any listed path is sensitive; gitignored files are not listed, so they don't trigger it, and `-u` looks at tracked files only.
  - Sensitive by default (matched on the file name): `.env` and `.env.*` except `.env.example`, `.env.sample`, `.env.template`, and `.env.dist`; `*.pem`, `*.key`, `*.p12`, `*.pfx`; `id_rsa`, `id_dsa`, `id_ecdsa`, `id_ed25519` (not their `.pub`); any name containing `credentials` or `.secret`.
  - Per repository: add patterns to `.claude/ogxo-guards-sensitive`, one extended regular expression per line matched against the path (`#` starts a comment), for example `(^|/)\.npmrc$` or `(^|/)\.envrc$`. Neither is in the defaults because both are often committed without secrets.
  - It does not see `git commit -a`, adds run through `xargs`, `$(...)`, scripts or aliases, or quoting it can't split on spaces. Keep secrets in `.gitignore`.
- **file-protection** (matcher `Edit|Write`): rejects edits to `node_modules/`, `vendor/`, `.git/`, and lock files (`package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `bun.lockb`, `Cargo.lock`, `go.sum`, `Gemfile.lock`, `poetry.lock`, `uv.lock`). It checks the `Edit`/`Write` tools only; shell commands can still change these files. Build output such as `dist/`, `build/`, or `generated/` is not protected, and other lock files (`composer.lock`, `Pipfile.lock`, `gradle.lockfile`) are not in the list.
- **large-file-guard** (matcher `Write`): rejects a single `Write` whose content is longer than 1,048,576 characters.

## Requirements

`jq` on `PATH`. Without it each hook prints a notice and does nothing (it never rejects a call it could not read).

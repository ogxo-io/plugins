# ogxo-guards

Safety hooks: reject a `git add` whose command text names a .env/credentials/.secret/.pem file, reject Edit/Write calls on lock files and on node_modules/, vendor/, and .git/ paths, and reject single file writes over 1,048,576 characters. Pattern-based, so it does not catch everything; see the README. Requires jq.

## Install

```bash
claude plugin marketplace add ogxo-io/plugins
claude plugin install ogxo-guards@ogxo
```

## What each hook does

All three are `PreToolUse` hooks. When one matches, it exits with code 2, which makes Claude Code reject that tool call and show Claude the reason.

- **env-file-guard** (matcher `Bash`): if the command is a `git add` or `git stage` (including `git -C <dir> add`) whose text names a `.env`/`.env.*` file (so `.env.example` too), anything containing `credentials` or `.secret`, or a `.pem` file, it is rejected. This is a pattern match on the command text only: `git add .`, `git add -A`, `git commit -a`, and globs still stage such files when they aren't gitignored, and names outside the list (`.envrc`, `id_rsa`, `*.key`) are not checked. Keep secrets in `.gitignore`.
- **file-protection** (matcher `Edit|Write`): rejects edits to `node_modules/`, `vendor/`, `.git/`, and lock files (`package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `bun.lockb`, `Cargo.lock`, `go.sum`, `Gemfile.lock`, `poetry.lock`, `uv.lock`). It checks the `Edit`/`Write` tools only; shell commands can still change these files. Build output such as `dist/`, `build/`, or `generated/` is not protected, and other lock files (`composer.lock`, `Pipfile.lock`, `gradle.lockfile`) are not in the list.
- **large-file-guard** (matcher `Write`): rejects a single `Write` whose content is longer than 1,048,576 characters.

## Requirements

`jq` on `PATH`. Without it each hook prints a notice and does nothing (it never rejects a call it could not read).

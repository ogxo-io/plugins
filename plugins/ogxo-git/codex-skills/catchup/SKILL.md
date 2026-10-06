---
name: catchup
description: "Restore branch context by reading changed files and task notes, with an optional path focus."
---

# Catch Up

Read `../../commands/catchup.md` relative to this skill's directory and follow
it. It is the Claude Code command; these adaptations apply in Codex:

- Ignore its frontmatter. `allowed-tools` does not configure this host.
- `$ARGUMENTS` is the optional file or directory path the user named in
  their request, not a command argument macro.
- Run Step 1's shell block at runtime as written and inspect its actual
  output. If no base resolves, ask which branch to compare against.

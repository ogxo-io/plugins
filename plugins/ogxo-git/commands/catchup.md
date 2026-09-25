---
description: Restore context by reading all files changed on the current branch
allowed-tools: Bash(git symbolic-ref:*), Bash(git diff:*), Read, Glob, Grep
argument-hint: "[path]"
---

# Catch Up with Branch Changes

Read all files changed in the current branch to quickly get up to speed when resuming work.

## When to use:

- Starting a new session on an existing branch
- After clearing or compacting context
- When resuming work after a break

## Instructions

Follow these steps to restore context:

### Step 1: Identify Changed Files

Detect the default branch and list all files changed on the current branch:

```bash
# Get the default branch (main or master)
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

# List all changed files compared to default branch
git diff --name-only "origin/${DEFAULT_BRANCH}...HEAD" 2>/dev/null || git diff --name-only origin/main...HEAD 2>/dev/null || git diff --name-only origin/master...HEAD
```

If `$ARGUMENTS` is provided, filter the changed files to only those matching the specified file or directory path.

### Step 2: Read Each Changed File

For each changed file:
1. Read the full file contents
2. Note what the file does and what changed

### Step 3: Check for Task Context

If the repo has a task or progress note the user keeps (e.g. `current-task.md` or a TODO file):
1. Read it
2. Summarize the in-progress task
3. Ask: "Found in-progress task: [title]. Continue from where we left off?"

### Step 4: Present Summary

Provide a brief summary of the branch state:

```
Branch: feature/xyz
Changed files: 5
  - src/auth.ts (authentication logic)
  - src/api/users.ts (user endpoints)
  - tests/auth.test.ts (auth tests)
  ...

In-progress task: [title or "None"]

Ready to continue. What would you like to work on?
```

## Arguments

- `$ARGUMENTS` -- Optional: specific file or directory path to focus the catchup on

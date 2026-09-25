---
description: Fast workflow for bug fixes with testing and immediate commit
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git commit:*), Read, Glob, Grep, Agent
---

# Quick Fix

You are a senior developer applying minimal, focused bug fixes.

## Current Context

GIT STATUS:

```
!`git status 2>/dev/null`
```

CHANGED FILES:

```
!`git diff --name-only 2>/dev/null`
```

Streamlined workflow for bug fixes with automated testing and commit generation.

## Workflow Steps

1. **Identify Issue**: Analyze the bug report or error and identify the root cause
2. **Apply Fix**: Make the minimal code changes to resolve the issue — don't refactor surrounding code
3. **Run Tests**: Run the focused test suite related to the fix first for fast feedback
4. **Regression Check**: Run the broader suite to ensure no other functionality broke
5. **Generate Commit**: Present the changed-file list and ask the user to stage what should be committed (staging is manual by design; suggest excluding plan files), then invoke git-commit-generator (`ogxo-git:git-commit-generator`) with the `fix:` type
6. **Report**: Summarize what was fixed with before/after behavior

## Optimized For

- Small, focused bug fixes
- Quick turnaround time
- Minimal scope changes
- Immediate testing feedback

## Usage

Invoke when you need to quickly fix a bug without the full feature workflow overhead. Keep changes minimal and focused on the specific issue.

---
name: quick-fix
description: "Apply a focused bug fix, verify runtime behavior and tests, and prepare a staged-only commit when requested."
---

# Quick Fix

1. Run `git status --short`, `git diff`, and `git diff --cached` separately at runtime. Read repository instructions and preserve existing edits. Capture the bug's actual error/output or a failing targeted test before selecting a fix.
2. Trace the failure through relevant code and callers, then implement the smallest change that addresses its cause.
3. Run focused tests and appropriate regression checks using the project's documented commands. Inspect actual output and report failures; do not claim a test passed merely from reading code.
4. Review the resulting diff and summarize before/after behavior and checks. If committing is requested and no files are staged, ask the user to stage the reviewed fix and pause the commit step. Do not stage files.
5. Read `../../skills/git-commit-generator/SKILL.md` relative to this skill directory and follow it for a Conventional Commit based only on staged changes. Session instructions and existing authorization govern committing. Run ordinary `git commit` with configured signing and hooks; omit attribution trailers unless explicitly requested.

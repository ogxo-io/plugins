---
description: Complete feature delivery workflow from code to PR with testing and security
allowed-tools: Bash(git status:*), Bash(git branch:*), Bash(git diff:*), Bash(git commit:*), Bash(npm:*), Bash(cargo:*), Bash(go:*), Read, Glob, Grep, Agent
---

# Ship Feature

You are a senior engineer responsible for quality-gated feature delivery.

## Current Context

GIT STATUS:

```
!`git status 2>/dev/null`
```

CURRENT BRANCH:

```
!`git branch --show-current 2>/dev/null`
```

Complete workflow to ship a feature with testing, security review, commit, and pull request creation.

## Workflow Execution

Execute in this order. Stop immediately if any quality gate fails:

1. **Security Review**: Invoke the `ogxo-review:security-auditor` agent to scan for OWASP Top 10 vulnerabilities
2. **Run Tests**: Execute test suite (npm test, cargo test, go test, etc.) to ensure all tests pass
3. **Build Verification**: Run production build to catch compilation or build errors
4. **Review & Stage**: Present the changed-file list and ask the user to stage what should ship (staging is manual by design; suggest excluding planning artifacts like `plan.md` or task notes)
5. **Generate Commit**: Invoke the **git-commit-generator** skill (`ogxo-git:git-commit-generator`) to create the conventional commit message
6. **Create PR**: Invoke the **pr-generator** skill (`ogxo-git:pr-generator`) to generate the pull request with test plan and issue-key linking

## Quality Gates

Before PR creation, this workflow runs these checks (the security step is an agent review, not a guarantee):

- A security review for OWASP Top 10 and common vulnerability patterns
- All unit and integration tests passing
- Production build succeeds without errors
- Conventional commit format compliance
- PR description includes test plan and issue references

## When to Use

Invoke this workflow when a feature is ready to ship and all code changes are complete. Use it to automate quality checks before PR creation.

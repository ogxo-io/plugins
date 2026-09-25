---
description: Focused security review of the current branch's changes against the default branch, plus a dependency vulnerability scan
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(git show:*), Bash(git remote show:*), Bash(grep:*), Bash(npm audit:*), Bash(cargo audit:*), Bash(pip-audit:*), Bash(govulncheck:*), Read, Glob, Grep, Agent
---

# Security Check

You are a senior security engineer conducting a focused security review of the changes on this branch. Your objective is to identify HIGH-CONFIDENCE security vulnerabilities with real exploitation potential — not theoretical issues or style concerns.

## Current Context

GIT STATUS:

```
!`git status 2>/dev/null`
```

FILES MODIFIED (branch diff):

```
!`git diff --name-only --merge-base origin/HEAD 2>/dev/null | grep . || echo "No changes detected (nothing differs from origin/HEAD, or origin/HEAD is not set)"`
```

COMMITS ON BRANCH:

```
!`git log --no-decorate origin/HEAD... 2>/dev/null || git log --no-decorate -5`
```

DIFF CONTENT:

```
!`git diff --merge-base origin/HEAD 2>/dev/null | grep . || echo "No diff content"`
```

## Objective

Review only the security implications newly introduced by the changes above; this is not a general code review. Report a finding only when you are confident (8+/10) it is exploitable, and skip theoretical, style, and low-impact issues, because a noisy report gets ignored. Prioritize vulnerabilities leading to unauthorized access, data breaches, or system compromise. This is read-only: do not modify files.

## Workflow

Execute in this order:

**Empty-scope guard.** If the changed file list came back empty (or reads `No changes detected`), **stop here — do not proceed to Phase 1.** Report which scope was resolved and that it contained no changes, and name the likely cause: wrong base ref, wrong branch, or genuinely nothing changed. Never review an empty diff: the run will come back "no issues found," which is indistinguishable from a clean security audit and will be read as an approval.

### Phase 1: Identify Vulnerabilities

Do the initial vulnerability identification yourself — you already hold the diff and these instructions:

1. **Repository context research** — Identify existing security frameworks, libraries, sanitization patterns, and the project's security model
2. **Comparative analysis** — Compare new code against established security patterns, flag deviations
3. **Vulnerability assessment** — Examine each modified file for security implications, trace data flows from untrusted sources to sensitive operations

### Phase 2: False Positive Filtering (Parallel Sub-Tasks)

For each vulnerability identified in Phase 1, spawn a parallel sub-task to validate it. Each sub-task should apply the false positive filtering rules below and assign a confidence score.

### Phase 3: Consolidate Results

Filter out any findings with confidence below 8/10. Compile the remaining findings into the final report.

## Security Categories to Examine

**Input Validation**: SQL injection, command injection, XXE, template injection, NoSQL injection, path traversal
**Authentication & Authorization**: Auth bypass, privilege escalation, session management flaws, JWT vulnerabilities
**Crypto & Secrets**: Hardcoded keys/passwords/tokens, weak algorithms, improper key storage, hardcoded IVs/salts, encryption without authentication (ECB mode, no HMAC), insufficient key length
**Injection & Code Execution**: RCE via deserialization, eval injection, XSS (reflected, stored, DOM-based)
**Data Exposure**: Sensitive data logging, PII handling violations, API data leakage, debug info exposure
**CORS & Headers**: Overly permissive CORS (`Access-Control-Allow-Origin: *` with credentials), missing security headers (CSP, X-Frame-Options, X-Content-Type-Options), exposed internal headers or stack traces
**Data Integrity**: Missing transactions for multi-step writes, read-modify-write without atomicity, missing idempotency for retryable operations, check-then-act patterns without atomic operations (balance check then deduction, inventory check then order)

## Dependency Scanning

After code review, run dependency vulnerability scanning for the project's package manager:

```bash
# Node.js
npm audit --json

# Rust
cargo audit

# Python
pip-audit

# Go
govulncheck ./...
```

Keep stderr: if a scanner is missing or fails, report "Dependencies scanned: no" with the error, not an empty section.

## False Positive Filtering

### Hard Exclusions — Automatically exclude findings matching these:

1. Denial of Service (DoS) vulnerabilities or resource exhaustion attacks
2. Secrets or credentials stored on disk if they are otherwise secured
3. Rate limiting concerns or service overload scenarios
4. Memory consumption or CPU exhaustion issues
5. Lack of input validation on non-security-critical fields without proven security impact
6. Input sanitization concerns for GitHub Action workflows unless clearly triggerable via untrusted input
7. A lack of hardening measures — only flag concrete vulnerabilities, not missing best practices
8. Race conditions or timing attacks that are theoretical rather than practical — **exception**: flag check-then-act (TOCTOU) and read-modify-write patterns in database/financial operations if confidence is 8+
9. Vulnerabilities related to outdated third-party libraries (handled by dependency scanning separately)
10. Memory safety issues in memory-safe languages (Rust, Go, etc.)
11. Files that are only unit tests or only used as part of running tests
12. Log spoofing concerns — outputting unsanitized user input to logs is not a vulnerability
13. SSRF vulnerabilities that only control the path (only flag if it controls host or protocol)
14. Including user-controlled content in AI system prompts
15. Regex injection or regex DoS concerns
16. Insecure documentation — do not report findings in markdown or doc files
17. A lack of audit logs

### Precedents

1. Logging high-value secrets in plaintext IS a vulnerability. Logging URLs is safe.
2. UUIDs can be assumed unguessable and do not need validation.
3. Environment variables and CLI flags are trusted values.
4. Resource management issues (memory/file descriptor leaks) are not valid findings.
5. Subtle web vulnerabilities (tabnabbing, XS-Leaks, prototype pollution, open redirects) — only report if extremely high confidence.
6. React and Angular are generally secure against XSS — do not report unless using `dangerouslySetInnerHTML`, `bypassSecurityTrustHtml`, or similar.
7. Most GitHub Action workflow vulnerabilities are not exploitable in practice — ensure a specific attack path before reporting.
8. Lack of permission checking in client-side JS/TS is not a vulnerability — backend is responsible.
9. Only include MEDIUM findings if they are obvious and concrete.
10. Most ipython notebook (*.ipynb) vulnerabilities are not exploitable — ensure a specific attack path.
11. Logging non-PII data is not a vulnerability even if sensitive.
12. Command injection in shell scripts is generally not exploitable — only report with a concrete untrusted input path.

## Confidence Scoring

For each finding, assign a confidence score from 1-10:

| Score | Meaning | Action |
|-------|---------|--------|
| **8-10** | High confidence — clear vulnerability with known exploitation methods | Include in report |
| **5-7** | Medium confidence — suspicious pattern requiring specific conditions | Exclude from final report |
| **1-4** | Low confidence — too speculative | Exclude |

**Only include findings with confidence 8 or above in the final report.**

## Required Output Format

Output findings in this exact markdown format:

```markdown
# Security Review: [Branch Name]

## Summary

- **Files reviewed**: [count]
- **Critical findings**: [count]
- **High findings**: [count]
- **Medium findings**: [count]
- **Dependencies scanned**: [yes/no]
- **Overall assessment**: [Secure / Concerns Found / Critical Issues]

## Findings

### Vuln 1: [Category]: `file.py:42`

- **Severity**: Critical | High | Medium
- **Confidence**: [8-10]/10
- **CWE**: CWE-XXX
- **Description**: [Clear explanation of the vulnerability]
- **Exploit Scenario**: [Concrete attack path with steps]
- **Recommendation**: [Specific fix with code example]

[Repeat for each finding...]

## Dependency Vulnerabilities

[Output from dependency scanner, if applicable]

## Positive Security Practices

[Note any good security patterns observed in the changes — secure defaults, proper input validation, etc.]
```

## Severity Guidelines

- **CRITICAL**: Directly exploitable → RCE, data breach, authentication bypass
- **HIGH**: Exploitable with specific conditions but significant impact
- **MEDIUM**: Defense-in-depth issues with concrete (not theoretical) impact

## Final Reminder

Focus on HIGH and MEDIUM findings only. Better to miss theoretical issues than flood the report with false positives. Each finding should be something a security engineer would confidently raise in a PR review.

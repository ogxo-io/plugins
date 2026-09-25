# Security Audit Playbook

Penetration-testing methodology, compliance-framework detail, report skeleton, and worked examples for the security-auditor agent. Read this for a full standalone audit or compliance assessment; the agent's inline methodology already covers per-diff OWASP + SAST review.

## Penetration Testing (authorized only)

Simulate real-world attacks only with written authorization and a defined scope.

**OWASP Testing Guide flow:**
1. **Information gathering** — passive reconnaissance, OSINT
2. **Configuration testing** — SSL/TLS config, HTTP headers, cloud storage permissions
3. **Authentication testing** — brute force, session management, password-reset flows
4. **Authorization testing** — path traversal, privilege escalation, IDOR
5. **Input validation** — injection, XSS, file-upload vulnerabilities
6. **Error handling** — information leakage in errors, stack traces
7. **Cryptography** — weak algorithms, improper key management
8. **Business logic** — race conditions, workflow bypasses, price manipulation

**Pre-engagement checklist:**
- [ ] Written authorization obtained
- [ ] Scope clearly defined (in-scope targets documented)
- [ ] Testing window agreed upon
- [ ] Backup/rollback plan in place
- [ ] Emergency contact established
- [ ] No destructive testing without explicit approval
- [ ] All findings documented with reproduction steps

## Authentication / Authorization Deep Dive

**Authentication:**
- **JWT**: algorithm confusion (`alg: none`), weak secrets, token expiration, refresh-token rotation
- **OAuth2/OIDC**: redirect-URI validation, state parameter, PKCE for mobile, token leakage
- **Sessions**: fixation, CSRF protection, secure cookie flags, timeout enforcement
- **MFA**: bypass attempts, backup-code security, rate limiting on verification
- **Password reset**: token predictability/expiration, account enumeration

**Authorization:**
- **RBAC**: role bypass, permission escalation, missing checks
- **IDOR**: direct object references without authorization (e.g., `/api/users/123`)
- **Path traversal**: unauthorized resources via path manipulation

**Checklist:** JWT signatures verified (no `alg: none`); OAuth2 redirect URIs strictly validated; CSRF tokens on state-changing operations; sessions invalidated on logout; MFA non-bypassable; reset tokens single-use and time-limited; authorization on every endpoint (not just frontend); no IDOR; account enumeration prevented.

## Compliance Frameworks

**OWASP ASVS** — Level 1 (basic hygiene, all apps), Level 2 (defense in depth, most apps), Level 3 (high assurance, critical apps).

**NIST CSF** — Identify (asset management, risk assessment), Protect (access control, data security), Detect (anomaly detection, monitoring), Respond (incident response, comms), Recover (recovery planning, improvements).

**PCI DSS** — secure network; protect cardholder data (encryption at rest/transit); vulnerability management program; strong access control; monitor and test networks; information security policy.

**Compliance checklist:** framework requirements mapped to findings; gaps documented; remediation aligned with compliance deadlines; evidence collected for audit trail; compensating controls documented.

## Full Report Skeleton

```markdown
# Security Audit Report: [Application Name]

## Executive Summary
**Audit Date**: [Date] · **Scope**: [Full / components] · **Methodology**: OWASP Testing Guide, SAST/DAST, pen testing
**Risk Summary**: Critical [X] · High [Y] · Medium [Z] · Low [W]
**Overall Security Posture**: [Critical / Poor / Fair / Good / Excellent]

## Findings

### Finding 1: [Title]
**Severity**: Critical|High|Medium|Low · **Confidence**: [8-10]/10 · **CWE**: [CWE-XXX] · **OWASP**: [A01:2025] · **CVSS**: [9.1]
**Description**: [vulnerability + business impact]
**Affected Components**: `src/api/users.ts:42`
**Reproduction Steps**: 1. … 2. … 3. …
**Proof of Concept**: [command / payload]
**Business Impact**: [data/systems at risk, regulatory implications]
**Remediation**: [specific fix with secure code example]
**References**: [OWASP / CWE links]

## Compliance Assessment
### OWASP ASVS Level 2: [65%]
- Authentication [80%] · Session Management [70%] · Access Control [45%] · Input Validation [75%] · Cryptography [90%]
### NIST CSF Coverage
- Identify / Protect / Detect / Respond / Recover [status each]

## Remediation Priorities
- Immediate (Critical/High): …
- Short-term (Medium): …
- Long-term (Low): …

## Recommendations
1. Integrate SAST/DAST into CI/CD
2. Developer OWASP Top 10 training
3. Automated dependency scanning (Snyk, Dependabot)
4. Quarterly reviews, annual pen tests
5. Documented, tested incident-response plan
```

## Worked Examples

**API security audit** — Plan (standard, OWASP Top 10 + API Top 10) → map endpoints and auth flows → OWASP testing (broken access control on 15 endpoints) → pen test (SQL injection in search) → report 3 critical / 8 high / 12 medium with reproduction steps and secure code.

**JWT review** — Plan (targeted auth review) → analysis (algorithm confusion, `alg: none` accepted) → testing (weak secret, no expiration validation) → 2 critical issues (token forgery possible) → remediation (RS256, expiry validation).

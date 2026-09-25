# Dependency Audit Playbook

License/outdated/supply-chain detection commands, phased upgrade strategy, report skeleton, and worked examples for the dependency-auditor agent. Read this when you need the exact detection command for an ecosystem or a report/upgrade template. The agent's inline tables cover severity, ecosystem detection, the license-compatibility matrix, and supply-chain indicators.

## License Detection Commands

```bash
npx license-checker --json --production   # Node.js
pip-licenses --format=json                # Python
go-licenses report ./...                  # Go
cargo license --json                      # Rust
```

Flag: GPL/AGPL in proprietary projects (legal risk); UNLICENSED or missing license (unknown terms); license changed between versions; multiple/dual licenses (choose a compatible option); custom or unusual licenses (legal review).

## Outdated Detection Commands

```bash
npm outdated --json                       # Node.js
pip list --outdated --format=json         # Python
cargo outdated --format json              # Rust
go list -u -m -json all                   # Go
bundle outdated                           # Ruby
```

## Supply-Chain Detection Commands

```bash
# npm package metadata
npm info <package> --json | jq '{name, maintainers, repository, scripts}'
# installed packages with install scripts (npm ls output has no scripts field)
grep -lE '"(preinstall|install|postinstall)"[[:space:]]*:' node_modules/*/package.json node_modules/@*/*/package.json
# package provenance
npm audit signatures
```

## Phased Upgrade Strategy

First analyze the dependency graph for cascading upgrades (what depends on the vulnerable package; will one upgrade force others; peer-dependency conflicts) and review changelogs for breaking changes (API changes, removed features, renamed exports, migration guides).

```
Phase 1: Patch updates (low risk, no breaking changes) — update all, run tests
Phase 2: Minor updates (low-medium risk) — one at a time, test after each
Phase 3: Major updates (high risk, breaking) — one at a time, follow migration guides, dedicated testing
Phase 4: Package replacements (highest risk) — swap deprecated packages, may require refactoring
```

## Report Skeleton

```markdown
# Dependency Audit Report: [Project Name]

## Executive Summary
**Audit Date**: [Date] · **Package Manager**: [npm/pip/cargo/…] · **Total Dependencies**: [N direct, M transitive]
**Risk Summary**: Critical [X] · High [Y] · Medium [Z] · Low [W] · License issues [L] · Outdated [O] · Supply-chain [S]
**Overall Dependency Health**: [Critical / Poor / Fair / Good / Excellent]

## Vulnerability Findings
### [CVE-XXXX-XXXX] — [Title]
**Severity**: [Critical|High|Medium|Low] · **CVSS**: [X.X]
**Package**: `name@installed` · **Fixed In**: `name@fixed`
**Dependency Type**: Direct | Transitive (via `parent`) · **Environment**: Production | Dev-only
**Description**: [impact] · **Advisory**: [GHSA/NVD/OSV link]
**Remediation**: upgrade `name` `X.Y.Z`→`A.B.C`; breaking changes: [none/list]; migration guide: [link]

## License Compliance
| Package | License | Issue | Action Required |
|---------|---------|-------|-----------------|
| `gpl-package` | GPL-3.0 | Incompatible with proprietary | Replace or isolate |

## Outdated Dependencies
| Package | Current | Latest | Behind | Breaking Changes |
|---------|---------|--------|--------|-----------------|
| `[package]` | [current] | [latest] | [N major / minor] | [Yes/No — migration guide] |

## Supply Chain Risks
| Risk | Package | Description |
|------|---------|-------------|
| Install script | `pkg` | Runs postinstall downloading binary |

## Remediation Plan
- Phase 1 (this week): critical patches, license replacements
- Phase 2 (next sprint): minor updates, medium CVEs
- Phase 3 (planned): major upgrades, deprecated-package migrations

## Recommendations
1. Automated dependency scanning (Dependabot / Renovate)
2. `npm audit` / `pip-audit` in CI
3. Pin versions in the lockfile
4. License compliance checks in CI
```

## Worked Examples

**Node.js audit** — Detect (npm, 45 direct / 890 transitive) → `npm audit` (3 critical, 8 high, 15 medium) → licenses (all MIT/Apache/BSD except 1 GPL-3.0 dev-only, acceptable) → outdated (12 major-behind, 30 minor) → report with Phase 1 (critical CVE fixes) + Phase 2 (major upgrades).

**Framework major upgrade (illustrative)** — graph shows which packages are tied to the old framework major → changelog review for breaking changes → cascade (renderer, testing library, styling library pinned to the old major) → Phase 1 (framework compat release) + Phase 2 (meta-framework majors one at a time) → list packages that need replacement.

**Commercial license review** — 120 production deps → 115 MIT/Apache/BSD compatible, 3 MPL-2.0 (file-level copyleft), 2 GPL-3.0 (incompatible) → flag GPL packages → identify MIT replacements → report with distribution chart and legal-review items.

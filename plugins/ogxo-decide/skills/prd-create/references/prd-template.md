# PRD Template

> Phase 3 of the prd-create flow writes a markdown PRD to `docs/prd/YYYY-MM-DD-<slug>.md` using this template. Substitute placeholders in `{{...}}` with real content captured during Phase 0–2. Sections marked `<!-- depth: ... -->` are conditionally rendered based on the depth tier chosen in Phase 0 (see SKILL.md §Inputs). When omitting a section, REMOVE its entire block AND renumber remaining sections to stay contiguous. The Header block (metadata at top) is always included.

## Template (verbatim)

````markdown
# PRD: {{feature name}}

## 1. Header

**Status:** Draft
**Owner:** {{user name (default: from git config user.name)}}
**Date:** {{YYYY-MM-DD}}
**Type:** {{new-feature | enhancement | pivot | deprecation}}
**Depth:** {{quick | standard | comprehensive}}

**Related artifacts:**
- War-room report: `{{path to docs/war-room/...md, or "none"}}`
- Brainstorming spec: `{{path to the brainstorming spec, or "none"}}`
- Pressure test: {{passed | N gaps recorded in Open Questions | skipped}}

---

## 2. Problem Statement
- **The problem:** {{1-2 sentences}}
- **Why now:** {{what changed}}
- **Cost of inaction:** {{concrete consequence — lost revenue / attrition / compliance / opportunity cost}}

## 3. Target Users
- **Primary persona:** {{role, context, current alternative or workaround}}
- **Secondary personas:** {{if any}}
- **NOT for:** {{exclusion list from clarifying-question Q3.3 or pressure-test theme 9}}

## 4. Goals & Success Metrics
- **Outcome 1:** {{goal statement}}
  - Metric: {{measurable indicator}}
  - Target: {{value + by-when}}
  - Type: {{leading | lagging}}
- **Outcome 2:** {{...}}

<!-- comprehensive only -->
**Counter-metrics (what we'd watch to ensure we're not inadvertently hurting):**
- {{counter-metric + threshold}}
<!-- end comprehensive -->

## 5. Non-Goals
- {{Explicit cut 1}}
- {{Explicit cut 2}}

<!-- standard+ -->
**Considered but deferred:** {{things we were tempted to include but consciously cut}}
<!-- end standard+ -->

## 6. Strategic Context
{{Fit with product vision (1-2 sentences) · competitive positioning · why-now relative to market/team capability}}

<!-- if war-room was run for this PRD -->
**Strategic decision (from war-room):**
- Chosen option: {{name + 1-line rationale}}
- Alternatives considered: {{names of other Pareto-optimal options from the war-room report}}
- Full report: `{{path to docs/war-room/...md}}`
<!-- end war-room -->

## 7. User Stories <!-- depth: standard, comprehensive -->

- **US1:** As a {{persona}}, I want {{capability}}, so that {{outcome}}.
- **US2:** ...
- **US3:** ...

<!-- comprehensive only -->
- **Highest-leverage story:** {{which US, and why}}
- **Riskiest story:** {{which US, and why}}
<!-- end comprehensive -->

## 8. Functional Requirements

**Must-have:**
- FR1: {{requirement}} {{→ maps to US1, US3}}
- FR2: ...

**Should-have:**
- FR3: ...

**Nice-to-have:**
- FR4: ...

<!-- if brainstorming was run for a specific FR -->
**Design exploration:** {{FR-N implementation approach explored in:}} `{{path to brainstorming spec}}`
<!-- end brainstorming link -->

## 9. Non-Functional Requirements <!-- depth: standard, comprehensive -->

- **Performance:** {{latency, throughput targets with concrete numbers}}
- **Security:** {{threat model summary, compliance requirements}}
- **Accessibility:** {{WCAG level or "not specified"}}
- **Reliability:** {{uptime SLO, error budget}}
- **Observability:** {{required logs, metrics, traces}}

## 10. Dependencies <!-- depth: standard, comprehensive -->

- **Upstream blockers:** {{specific systems/teams/contracts that must complete first}}
- **Downstream consumers:** {{teams/products affected by this shipping}}
- **External systems:** {{vendor APIs, infrastructure, third-party services with concrete names}}

## 11. Open Questions

{{Bulleted list of unresolved items. Each entry tagged with originating context:}}

- `[from Section N <name>, declined sub-tool offer]` {{question + user's stated reason}}
- `[from pressure test Q-M <theme>]` {{question + user's actual answer}}
- `[from Section N clarifying question]` {{user said "I don't know" / no concrete answer}}

(If section is empty, write: "None — all questions resolved.")

## 12. Rollout Plan <!-- depth: comprehensive only -->

- **Strategy:** {{feature flag | phased % rollout | dark launch | big-bang}}
- **Phase 1:** {{rollout description + audience}} → success criteria: {{metric + threshold}}
- **Phase 2:** {{...}} → success criteria: {{...}}
- **Rollback mechanism:** {{kill switch, feature flag toggle, schema migration revert plan}}

## 13. Appendix <!-- depth: standard, comprehensive -->

- {{Linked research, user interviews, telemetry queries, prior art}}
- {{Re-linked artifacts from header for convenience}}
````

## Notes for the Skill

- **Section numbering:** The PRD output uses sections **1 through 13** as enumerated in the template above. Section 1 = Header (metadata block at top); Section 2 = Problem Statement; ... Section 13 = Appendix. When a section is omitted for the depth tier, REMOVE the section AND renumber subsequent sections to stay contiguous (no gaps).

- **Header field defaults:**
  - `{{user name}}` → `git config user.name` output if available, else "Unknown"
  - `{{date}}` → today's date in YYYY-MM-DD
  - `{{type}}` → from Phase 0 type detection
  - `{{depth}}` → from `--depth` flag

- **Open Questions formatting:** Each entry is a single bullet with a tag in backticks identifying its origin, followed by the question and current state. Tag formats:
  - `[from Section N <name>, declined sub-tool offer]` — user declined a war-room or brainstorming offer
  - `[from pressure test Q-M <theme>]` — pressure-test answer was weak/unknown
  - `[from Section N clarifying question]` — user answered "I don't know" to a clarifying question

- **War-room embedding (Section 6 Strategic Context):** When a war-room report was generated (either pre-emptively via `--war-room` flag or via Phase 2 spawn for Section 6), embed a 3-bullet summary block: chosen option + 1-2 alternatives + link to full report. NEVER paste the full report inline.

- **Brainstorming link (Section 8 Functional Requirements):** When a brainstorming spec was generated, append the "Design exploration" line under the relevant FR. Multiple brainstorming specs → multiple lines.

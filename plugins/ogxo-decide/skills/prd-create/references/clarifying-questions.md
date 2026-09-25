# Clarifying Questions per PRD Section

> Question bank for Phase 1 (Section-by-Section Requirements Gathering). Each PRD section has 2–4 ranked questions. Phase 1 uses the top N questions based on depth tier (quick=1, standard=2, comprehensive=3, comprehensive-with-sub-tools=4). Each question lists: type (multi-choice or free-text), default options for multi-choice, and integration triggers that signal an opportunity to OFFER `/ogxo-decide:war-room` or `/superpowers:brainstorming` (never auto-spawn — only offer).

## How to use this file

**Tool selection by question type:**
- **Multi-choice questions:** use `AskUserQuestion` with the stated options (requires 2–4 options).
- **Free-text questions:** ask in plain conversation text, then STOP and wait for the user's reply on the next turn. Do NOT call `AskUserQuestion` — it requires `options` of length ≥2 and will fail with `InputValidationError`.

In Phase 1, for each PRD section, the skill:
1. Reads the questions in this file for that section.
2. Picks the top N based on depth.
3. Asks them one at a time, using `AskUserQuestion` for multi-choice and plain conversation for free-text (see above).
4. After capturing each answer, checks the user's answer text against the question's integration triggers; if a trigger fires, OFFER the relevant sub-tool.

---

## Section 2 — Problem Statement

### Q2.1 — Problem core (priority 1, all depths)
- **Question:** What user/business problem does this solve? Name it in one or two sentences.
- **Type:** free-text
- **Triggers:** none

### Q2.2 — Urgency (priority 2, standard+)
- **Question:** Why now? What changed that makes this urgent?
- **Type:** free-text
- **Triggers:** none

### Q2.3 — Cost of inaction (priority 3, comprehensive)
- **Question:** What concretely happens if we don't solve this?
- **Type:** multi-choice
- **Options:**
  - Lost revenue / customers (specify estimate)
  - User attrition / disengagement
  - Compliance / regulatory exposure
  - Competitive loss
  - Opportunity cost only (no acute pain)
  - Other (free-text)
- **Triggers:** none

### Q2.4 — Manifestation (priority 4, comprehensive)
- **Question:** Give a concrete example of how this problem shows up today.
- **Type:** free-text
- **Triggers:** none

---

## Section 3 — Target Users

### Q3.1 — Primary persona (priority 1, all depths)
- **Question:** Who's the primary user? Describe their role and context.
- **Type:** free-text
- **Triggers:** none

### Q3.2 — Current alternative (priority 2, standard+)
- **Question:** What does the primary user do TODAY when they hit this problem?
- **Type:** free-text
- **Triggers:** none

### Q3.3 — Exclusion (priority 3, comprehensive)
- **Question:** Who is explicitly NOT a target user for this feature?
- **Type:** free-text
- **Triggers:** none

---

## Section 4 — Goals & Success Metrics

### Q4.1 — Headline metric (priority 1, all depths)
- **Question:** What's the single headline outcome metric this moves?
- **Type:** free-text (with examples: MAU, retention, conversion rate, NPS, latency, error rate)
- **Triggers:**
  - If answer is vague ("improve UX", "make it better", "happiness") with no measurable indicator → flag for self-review but do NOT offer war-room or brainstorming. The fix is asking Q4.2 more aggressively.

### Q4.2 — Target value (priority 2, standard+)
- **Question:** By how much, by when?
- **Type:** free-text
- **Triggers:** none

### Q4.3 — Indicator type (priority 3, comprehensive)
- **Question:** Is this a leading or lagging indicator?
- **Type:** multi-choice
- **Options:** Leading / Lagging / Both / Unsure (→ becomes Open Question)
- **Triggers:** none

### Q4.4 — Counter-metric (priority 4, comprehensive)
- **Question:** What counter-metric should we watch — something we might inadvertently hurt by chasing the headline?
- **Type:** free-text (allow "I don't know" → goes to Open Questions)
- **Triggers:** none

---

## Section 5 — Non-Goals

### Q5.1 — Explicit cuts (priority 1, all depths)
- **Question:** What's explicitly OUT of scope for this PRD? (List 2-5 items)
- **Type:** free-text
- **Triggers:** none

### Q5.2 — Tempted-but-cut (priority 2, standard+)
- **Question:** What were you tempted to include but consciously cut, and why?
- **Type:** free-text
- **Triggers:** none

---

## Section 6 — Strategic Context

### Q6.1 — Vision fit (priority 1, all depths)
- **Question:** How does this fit our product vision?
- **Type:** free-text
- **Triggers:**
  - "we haven't decided" / "we're not sure" / "it's debated" → **OFFER /ogxo-decide:war-room**
  - "this is a pivot from X" → **OFFER /ogxo-decide:war-room** (the pivot itself deserves war-room treatment)

### Q6.2 — Competitive position (priority 2, standard+)
- **Question:** What's the competitive position — are we leader, follower, or contrarian?
- **Type:** multi-choice
- **Options:** Leader (first-mover) / Follower (catching up to peers) / Contrarian (deliberately different) / Unclear
- **Triggers:**
  - Answer "Unclear" → **OFFER /ogxo-decide:war-room** for "competitive positioning"

### Q6.3 — Prior consideration (priority 3, comprehensive)
- **Question:** Have we built/considered/declined this before? If yes, what changed?
- **Type:** free-text
- **Triggers:** none

---

## Section 7 — User Stories

(Only rendered for depth `standard` and `comprehensive`.)

### Q7.1 — Top stories (priority 1, standard+)
- **Question:** List 3–5 user stories in "As a <persona>, I want <capability>, so that <outcome>" format.
- **Type:** free-text (multi-line)
- **Triggers:** none

### Q7.2 — Leverage & risk (priority 2, comprehensive)
- **Question:** Of these stories, which is highest-leverage (biggest impact)? Which is riskiest (most likely to fail)?
- **Type:** free-text
- **Triggers:** none

---

## Section 8 — Functional Requirements

### Q8.1 — Must-have requirements (priority 1, all depths)
- **Question:** List the must-have functional requirements (FR). What MUST this do?
- **Type:** free-text (multi-line)
- **Triggers:**
  - User's answer mentions "we need to figure out how" / "the implementation isn't settled" / "we have a few approaches" → **OFFER /superpowers:brainstorming** for the specific requirement
  - Complex behavior named without a mechanism (e.g., "auto-categorize uploads") → **OFFER /superpowers:brainstorming**

### Q8.2 — Should/nice-to-have (priority 2, standard+)
- **Question:** What are the should-have and nice-to-have requirements, separated?
- **Type:** free-text (multi-line)
- **Triggers:** same as Q8.1

### Q8.3 — Unsettled approaches (priority 3, comprehensive)
- **Question:** Are there any requirements where the implementation approach is genuinely unsettled?
- **Type:** free-text (allow listing or "no")
- **Triggers:** Each unsettled approach → **OFFER /superpowers:brainstorming** per item

---

## Section 9 — Non-Functional Requirements

(Only rendered for depth `standard` and `comprehensive`.)

### Q9.1 — Performance targets (priority 1, standard+)
- **Question:** What are the performance targets — latency, throughput, payload sizes?
- **Type:** free-text
- **Triggers:** none

### Q9.2 — Security & compliance (priority 2, standard+)
- **Question:** What are the security and compliance requirements? (auth, authorization, audit, PII, GDPR, SOC2, etc.)
- **Type:** free-text
- **Triggers:**
  - User answers with significant uncertainty ("we should probably figure out compliance") → **OFFER /ogxo-decide:war-room** (compliance has strategic implications)

### Q9.3 — Accessibility (priority 3, comprehensive)
- **Question:** What's the accessibility target?
- **Type:** multi-choice
- **Options:** WCAG 2.1 AA / WCAG 2.1 AAA / WCAG 2.2 AA / Not specified yet (→ Open Question)
- **Triggers:** none

### Q9.4 — Reliability SLO (priority 4, comprehensive)
- **Question:** What's the reliability SLO — uptime target, error budget?
- **Type:** free-text (allow "use platform default")
- **Triggers:** none

---

## Section 10 — Dependencies

(Only rendered for depth `standard` and `comprehensive`.)

### Q10.1 — Upstream blockers (priority 1, standard+)
- **Question:** What upstream systems, teams, or contracts must complete BEFORE this can ship?
- **Type:** free-text
- **Triggers:** none

### Q10.2 — Downstream consumers (priority 2, standard+)
- **Question:** Who/what depends on THIS shipping (downstream consumers)?
- **Type:** free-text
- **Triggers:** none

### Q10.3 — External vendors (priority 3, comprehensive)
- **Question:** Any external vendor / API / infrastructure dependencies?
- **Type:** free-text
- **Triggers:**
  - "we're not sure which vendor" / "we're evaluating X vs Y" → **OFFER /ogxo-decide:war-room** for vendor selection

---

## Section 11 — Open Questions

No clarifying questions for this section. It is auto-populated from:
- Declined sub-tool offers throughout Phase 1
- Pressure-test weak/unknown answers from Phase 0.5 (when user chose Continue)
- User answers of "I don't know" or equivalent throughout other section's questions

---

## Section 12 — Rollout Plan

(Only rendered for depth `comprehensive`.)

### Q12.1 — Strategy (priority 1, comprehensive)
- **Question:** How will this be rolled out?
- **Type:** multi-choice
- **Options:** Feature flag (gradual) / Phased % rollout / Dark launch (instrument-only) / Big-bang / Other (specify)
- **Triggers:** none

### Q12.2 — Rollback mechanism (priority 2, comprehensive)
- **Question:** What's the rollback mechanism if things break in production?
- **Type:** free-text
- **Triggers:** Answer mentions complex rollback steps → **OFFER /superpowers:brainstorming** for rollback design

### Q12.3 — Per-phase success criteria (priority 3, comprehensive)
- **Question:** For each rollout phase, what's the go/no-go criterion to proceed to the next?
- **Type:** free-text
- **Triggers:** none

---

## Section 13 — Appendix

No clarifying questions. Auto-populated with:
- War-room report path (re-linked from header)
- Brainstorming spec path (re-linked from header)
- Any user-provided research links from earlier sections

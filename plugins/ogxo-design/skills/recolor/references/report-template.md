# Recolor Report Template

The single consolidated deliverable, written to
`docs/recolor/YYYY-MM-DD-color-system.md` in the target project. Every section
is required; write "none" or "not run" rather than omitting. No placeholders —
a section you can't fill honestly is a finding in Remaining Risks.

```markdown
# Color System — <Product Name> — <date>

## 1. Product Assessment
- What the product does, who uses it, the 2–3 actions that matter most
- Desired perceptual/emotional qualities (with the evidence they're inferred from)
- Industry color conventions in play; cultural/regional considerations
- Existing palette: strengths, weaknesses (cite audit rows)
- Assumptions made (clearly labeled)

## 2. Color Audit
| Value(s) | Locations | Freq | Intended role | Actual role(s) | Contrast | Verdict | Target token |
|----------|-----------|------|---------------|----------------|----------|---------|--------------|
Systemic problems found (hierarchy, duplication, semantics, dark mode, CVD…),
each with concrete file references.

## 3. Direction Comparison
One subsection per direction: swatch table (hex + oklch), rationale,
emotional/product fit, differentiation, computed accessibility spot-checks,
advantages, risks, light/dark notes.

### Scoring
| Criterion (weight) | Dir A | Dir B | Dir C |
|--------------------|-------|-------|-------|
Score 1–5 per criterion. Default weights — adjust with justification:
accessibility ×3, product/user fit ×3, primary-action clarity ×2,
semantic clarity ×2, visual hierarchy ×2, cross-theme performance ×2,
CVD resilience ×2, brand distinction ×1, data-viz compatibility ×1,
maintainability ×1, implementation risk ×1.
Weighted totals + one paragraph: why the winner wins, why each loser loses.

## 4. Decision
Selected direction; whether the brand color was retained / adjusted / replaced
and why; user checkpoint outcome (chosen option, or `--auto`); expected product
outcomes.

## 5. Token System
Primitive ramps (hex + oklch), semantic mapping for light AND dark themes,
component tokens, interaction-state mapping, status mapping, chart palette.

## 6. Migration Map
| Old value | Old usage (file) | New token | New value | Reason |
|-----------|------------------|-----------|-----------|--------|

## 7. Implementation Summary
Files modified, components updated, values removed, tokens added, themes
updated, technical decisions (and any dependency added, with justification).

## 8. Accessibility Results
Contrast matrix output (both themes) verbatim; corrected failures
(before → after); CVD results for status/chart pairs; deliberate exceptions;
unresolved limitations. Checks not run are listed as not run.

## 9. Visual Comparison
Before/after screenshots per key screen — or the statement that visual evidence
is code-derived (see baseline note in audit).

## 10. Verification
| Check | Command | Result |
|-------|---------|--------|
Formatting / lint / typecheck / tests / build — exact commands and outcomes.
Never claim a pass that wasn't run; include exact errors for failures.

## 11. Remaining Risks & Follow-up
Unmigrated components (with files), areas needing product/user validation,
brand implications, recommended next steps.
```

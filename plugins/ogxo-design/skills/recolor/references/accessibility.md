# Accessibility Requirements

WCAG 2.2 AA is the floor, not the target. Aim for AAA on body text and
high-value flows where the design allows. Every number below is verified with
`scripts/color_tools.py` — a ratio that was never computed does not exist.

## Contrast Minimums (WCAG 2.2)

| Element | AA | AAA |
|---------|----|----|
| Normal text (< 24px / < 18.66px bold) | 4.5:1 | 7:1 |
| Large text (≥ 24px = 18pt / ≥ 18.66px = 14pt bold) | 3:1 | 4.5:1 |
| UI components & graphical objects (borders that carry state, icons, focus indicators, chart marks) | 3:1 | — |
| Disabled (inactive) components | exempt, but keep legible where feasible | — |
| Placeholder text | not exempt — it is text: 4.5:1 (3:1 if large) | 7:1 |

Focus indicators: at AA, the ring is a graphical object under 1.4.11 Non-text
Contrast (≥ 3:1 against adjacent colors), and 2.4.11 Focus Not Obscured
requires it not be entirely hidden by other content. 2.4.13 Focus Appearance
(AAA) adds an area at least a 2 CSS px perimeter and ≥ 3:1 between focused and
unfocused states — target it where the design allows. Never remove a focus
style without an equal replacement.

## The Verification Matrix

Build one `pairs.json` per theme covering every meaningful combination, and
keep it in the target project (`docs/recolor/contrast-light.json`, `-dark.json`)
so the check is repeatable:

- body / secondary / muted text on every background token they appear on
- link text on canvas and on surfaces
- button label on every button variant background (default + hover + active +
  disabled noted as exempt)
- icon and border-carrying-state colors on their surfaces (`"ui": true`)
- focus ring on canvas, surface, and both button backgrounds (`"ui": true`)
- status foregrounds on their `*-surface` backgrounds, and status borders on canvas
- text over gradients: check against the gradient's **lightest and darkest
  stops** — both must pass
- text over images: only passes with a guaranteed scrim/overlay; check text
  against the scrim color at its weakest point
- chart series labels/legend text, and adjacent chart series against each other
  (`"ui": true`)
- selected/hover row or item backgrounds vs. the text sitting on them

Run:

```bash
# color_tools.py lives in this skill's install dir, not the target repo
python3 ${CLAUDE_PLUGIN_ROOT}/skills/recolor/scripts/color_tools.py matrix docs/recolor/contrast-light.json
python3 ${CLAUDE_PLUGIN_ROOT}/skills/recolor/scripts/color_tools.py matrix docs/recolor/contrast-dark.json
```

Exit code 1 means at least one AA failure — fix the token values (usually by
moving one ramp step) and re-run. Ratios go in the final report verbatim.

## Never Color Alone

Color may reinforce meaning, never solely carry it (WCAG 1.4.1):

- Form errors: icon + message text, not just a red border
- Status: icon or label alongside the colored dot/badge
- Links in prose: underline (or equivalent), not color-only
- Charts: direct labels, patterns, or ordered legends; positive/negative also
  encoded by sign/direction
- Required fields, diffs, validation, toggles: shape/text/position cue in
  addition to hue

## Color-Vision Deficiency Checks

For every pair of colors users must *tell apart* (not read text on — status
colors vs. each other, adjacent chart series, on/off states):

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/skills/recolor/scripts/color_tools.py cvd '#16a34a' '#dc2626'
```

The tool simulates protanopia, deuteranopia, and tritanopia (Machado et al.
2009 matrices) and flags pairs whose simulated ΔE-OK falls below 0.06 — those
pairs need either a lightness gap or a non-color cue. Fix by varying lightness
between the pair, not just hue.

Achromatopsia and low-contrast sensitivity are covered by the squint test:
verify hierarchy and state remain readable in forced grayscale (browser
DevTools rendering emulation when available; otherwise the lightness values in
the token table serve as evidence).

## Honest Reporting

The report's accessibility section lists: passing pairs (with ratios), failing
pairs that were corrected (before → after), deliberate exceptions (with
justification — e.g. disabled content), and unresolved limitations. A check
that wasn't run is reported as "not run", never implied as passing.

# Color Audit Playbook

How to find every color in a codebase, classify it, and establish the baseline
before proposing anything. Output feeds the audit table in `report-template.md`.

## Step 1: Detect the Styling Stack

Check in this order — the stack determines both the grep patterns and the
eventual token implementation:

| Evidence | Stack | Token home |
|----------|-------|------------|
| `tailwind.config.{js,ts}` with `theme.colors` | Tailwind v3 | config `theme.extend.colors` |
| `@theme` block in a CSS entry file | Tailwind v4 | `@theme` CSS variables |
| `components.json` + `app/globals.css` HSL/OKLCH vars | shadcn/ui | CSS variables consumed by Tailwind |
| `:root { --* }` custom properties | Plain CSS vars | the `:root` / `[data-theme]` blocks |
| `$variable` / `@use 'sass:color'` | SCSS | variables/map partial |
| `styled-components`, `@emotion`, `ThemeProvider` | CSS-in-JS | theme object |
| `createTheme(` (MUI), `extendTheme(` (Chakra/Mantine) | Component library | library theme config |
| `Colors.xcassets`, `colors.xml`, Flutter `ThemeData` | Native mobile | platform color assets |

Multiple stacks can coexist (e.g. Tailwind + a stray `styles.css`). Audit all of them.

## Step 2: Inventory Every Color

Run these searches from the project root (exclude `node_modules`, build output,
lockfiles, generated files). `--include` takes one glob per flag — grep does not
expand `*.{css,scss}` braces, so a braced glob silently matches nothing. An
empty result is a signal to check the globs and paths, not proof of no colors.

```bash
STYLE=(--include='*.css' --include='*.scss' --include='*.sass' --include='*.less')
CODE=(--include='*.js' --include='*.jsx' --include='*.ts' --include='*.tsx' \
      --include='*.vue' --include='*.svelte' --include='*.html')
SKIP=(--exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build \
      --exclude-dir=.next --exclude-dir=coverage)

# Hex (3, 4, 6, 8 digit)
grep -rEn "${STYLE[@]}" "${CODE[@]}" "${SKIP[@]}" \
  '#[0-9a-fA-F]{3,8}\b' . | grep -vE 'id=|href=|url\(#'

# Functional notations
grep -rEn "${STYLE[@]}" "${CODE[@]}" "${SKIP[@]}" \
  '(rgba?|hsla?|oklch|oklab|color-mix|light-dark)\(' .

# Named CSS colors used as values (high-noise; scan the hits)
grep -rEn "${STYLE[@]}" "${SKIP[@]}" \
  ':\s*(white|black|red|blue|green|gray|grey|orange|purple|pink|transparent)\b' .

# Tailwind palette utilities (raw palette = untokenized color decision)
grep -rEoh "${CODE[@]}" "${SKIP[@]}" \
  '(text|bg|border|ring|fill|stroke|from|via|to|shadow|outline|decoration|accent|caret)-(slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose)-[0-9]{2,3}' . | sort | uniq -c | sort -rn

# Existing variables/tokens already defined (-e: the pattern starts with --)
grep -rEn "${STYLE[@]}" "${SKIP[@]}" -e '--[a-z-]*(color|bg|surface|text|border|brand|primary|accent)[a-z-]*\s*:' .
```

Don't forget the places greps miss: SVG `fill`/`stroke` attributes, inline
`style=` props, canvas/chart configs (Chart.js `backgroundColor`, Recharts
`fill`, ECharts themes, d3 scales), email templates, `manifest.json` /
`theme-color` meta tags, favicons, CSS-in-JS template literals, and
shadow/gradient/overlay values where color hides inside a longer value.

## Step 3: Build the Audit Table

Group equivalent and near-duplicate values (ΔE-OK < 0.02 — verify with
`scripts/color_tools.py cvd A B`, the `dE-OK` line). For each group record:

- **Value(s)** — every raw literal in the group
- **Locations** — files (with counts, not every line)
- **Frequency** — total occurrences
- **Intended role** — what it's supposed to mean (primary action, muted text…)
- **Actual role(s)** — every way it's really used; mismatches are findings
- **Contrast** — computed ratio against the background(s) it appears on
- **Verdict** — keep / merge / retire / re-role
- **Target token** — the semantic token it should become

## Step 4: Diagnose Systemic Problems

Check the palette for each of these; cite concrete instances, not vibes:

- Weak hierarchy: primary action doesn't visually outrank secondary content
- Overused brand color: it marks headings, links, borders, icons, and buttons alike, so it marks nothing
- Too many unrelated hues, or excessive saturation across large surfaces
- Insufficient contrast (run the matrix — see `accessibility.md`)
- Inconsistent semantics: same color means different things in different screens, or the same state uses different colors
- Status colors too close to each other or to the brand color (run `cvd` on every status pair)
- Interactive states too subtle (hover/active/selected barely distinguishable) or missing (no visible focus)
- Poor dark-mode behavior: colors inverted naively, shadows invisible, saturated text vibrating on dark surfaces
- Color as the only carrier of meaning (charts, form errors, status dots)
- Raw values repeated instead of referenced (count from Step 2 is the evidence)

## Step 5: Capture the Baseline

Tiered by what's available — never block the audit on tooling:

1. **Browser tooling available and app runs** (a browser-automation tool,
   Playwright, or the project's Storybook): screenshot the key screens and states — navigation,
   primary CTA flow, forms with validation, dark mode if present. These are the
   "before" images for the final report.
2. **App not runnable**: record the baseline as the audit table plus the
   computed contrast matrix. State in the report that visual evidence is
   code-derived.

Save baseline artifacts under `docs/recolor/baseline/` in the target project.

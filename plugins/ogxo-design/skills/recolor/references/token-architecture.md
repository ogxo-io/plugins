# Token Architecture and Migration

The three-layer token system, per-stack implementation, and the refactoring
rules that keep the migration safe.

## Layer 1: Primitive Tokens

Raw scales, no meaning attached. One ramp per family actually needed —
`neutral`, `primary`, plus `secondary`/`accent` only if the chosen direction
uses them, and `success` / `warning` / `error` / `info`.

- Steps: `50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950`
- Build in OKLCH (constant hue, tapered chroma, perceptually even lightness);
  `scripts/color_tools.py ramp '#seed' --name primary` gives a starting point —
  hand-tune, especially the 400–600 usability band and both extremes
- Status ramps can be shorter (100/500/700/900 is often enough); don't mint
  eleven steps nobody will use

## Layer 2: Semantic Tokens

Purpose-named, theme-switchable. **Identical names in light and dark themes** —
only the primitive they point to changes. Core set (extend only when a real
usage exists):

```
background: canvas, surface, subtle, elevated, inverse, overlay
text:       primary, secondary, muted, disabled, inverse, link
border:     default, subtle, strong
action:     primary, primary-hover, primary-active, primary-disabled,
            secondary, secondary-hover, destructive, destructive-hover
focus:      ring
status:     success, success-surface, success-border,
            warning, warning-surface, warning-border,
            error,   error-surface,   error-border,
            info,    info-surface,    info-border
chart:      categorical-1..6, positive, negative  (if the app has data viz)
```

Rules:

- Components consume **semantic tokens only**. Primitives appear in exactly one
  place: the semantic mapping.
- Hover/active states map to different ramp steps (600 → 700), not
  opacity overlays — opacity produces unpredictable contrast over varied
  backgrounds.
- `*-surface` status tokens are the pale backgrounds for banners/toasts; the
  paired `status.*` foreground must pass 4.5:1 on them. Verify with the matrix.
- Avoid pure `#000`/`#fff` for large areas when softened neutrals (950/50) sit
  better — but don't invent off-whites where the design genuinely wants pure.

## Layer 3: Component Tokens

Only when a semantic token can't express the need (e.g. `input-border-error`,
`navigation-item-selected`). Named by purpose, never by appearance: no
`blue-button`, `gray-card`, `dark-text`. If two component tokens resolve to the
same semantic token, delete one.

## Per-Stack Implementation

**Tailwind v4** — define in the `@theme` block; utilities are generated from it:

```css
@theme {
  --color-primary-500: oklch(0.62 0.19 262);
  --color-surface: var(--color-neutral-50);
}
```

Theme switch via `@layer base` + `[data-theme="dark"]` overriding the semantic
variables (or `light-dark()` where browser support allows).

**Tailwind v3** — primitives in `theme.extend.colors`; semantic tokens as CSS
variables consumed with `rgb(var(--surface) / <alpha-value>)`; dark values under
`.dark` / `[data-theme="dark"]`.

**shadcn/ui** — keep its existing semantic contract (`--background`,
`--foreground`, `--primary`, `--ring`, …) and re-point the values; don't invent
a parallel vocabulary. Extend with the same naming style if gaps exist.

**Plain CSS / SCSS** — primitives and semantic vars on `:root`, dark overrides
on `[data-theme="dark"]` (or `prefers-color-scheme` with an override hook).
In SCSS, keep scales in a map and emit CSS variables; don't compile literals
into every rule.

**CSS-in-JS (styled-components / Emotion)** — primitives as a plain object;
light/dark theme objects mapping semantic names to primitives; components read
`theme.text.primary` etc. via `ThemeProvider`.

**MUI / Chakra / Mantine** — feed primitives into the library's own theme
system (`createTheme` palette, `extendTheme` semanticTokens). Use the
library's semantic slots rather than bypassing them with raw CSS.

**Charts** — expose `chart.categorical-*` tokens to the chart config layer;
chart libraries usually take a colors array, so build that array from the
tokens in one module instead of per-chart literals.

## Migration Order

Work from foundations outward so every later step consumes the earlier one:

1. Primitive palette (new file/block; nothing consumes it yet — zero risk)
2. Semantic tokens + light/dark theme mappings
3. Global styles (body, canvas, typography colors, focus ring)
4. Shared UI components (buttons, inputs, cards — highest leverage)
5. Navigation + primary CTAs
6. Forms and validation states
7. Overlays: dialogs, menus, toasts, tables, banners
8. Charts and data viz
9. Feature-specific components (sweep the audit table's remaining rows)
10. Delete retired values and unused legacy variables; run the Step 2 greps
    from `audit-playbook.md` again — remaining raw literals are either
    intentional (document why) or missed (fix)

## Refactoring Rules

- **No blind global search-and-replace.** The audit table maps old value →
  token *per usage role*; the same `#333` may become `text.primary` in one file
  and `border.strong` in another. Replace in context.
- Preserve layout, spacing, typography, and behavior. This is a color refactor;
  the only allowed non-color changes are those accessibility requires (e.g.
  adding a focus style, an icon to a color-only status).
- Keep the semantic layer honest: if you catch yourself adding
  `text.primary-but-slightly-lighter`, you need a new step or a new role, not
  a mutant token.
- Normalize gradients, illustrations, and chart palettes through tokens where
  practical; leave raster assets alone but note them in the report.
- Follow the project's existing conventions (file layout, naming style, lint
  rules). Add no new dependency unless strictly necessary and justified in the
  report.
- Never leave the app half-migrated silently — anything not migrated goes in
  the report's "Remaining work" with file references.

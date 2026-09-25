# Color Theory for Interface Design

The principles used to construct and judge color directions. Apply them to real
interface contexts — a palette that is mathematically harmonious but fails in a
data table is a failed palette.

## Hue Relationships

| Scheme | Structure | Interface fit |
|--------|-----------|---------------|
| Monochromatic | One hue, varied lightness/chroma | Calm, cohesive; needs strong neutrals + one accent or CTAs disappear |
| Analogous | 2–3 adjacent hues (≤60° apart) | Harmonious, low tension; keep one hue dominant |
| Complementary | Opposite hues (~180°) | Maximum accent pop; use the complement sparingly (CTAs, alerts), never 50/50 |
| Split-complementary | Hue + the two neighbors of its complement | Complementary energy with less vibration; good for product + status colors |
| Triadic | Three hues ~120° apart | Rich but noisy; mute two, saturate one; useful for data viz |

**Proportion rule (60-30-10):** ~60% neutral surfaces, ~30% secondary/structural
color, ~10% saturated accent. Saturated color spends attention — budget it for
primary actions, state, and meaning. When everything is colorful, nothing is.

## Perceptual Structure

- **Luminance carries hierarchy.** Squint-test: with hue removed, the layout's
  hierarchy must survive. Lightness contrast, not hue contrast, separates
  figure from ground and passes WCAG.
- **Use OKLCH to build scales.** Equal lightness steps in OKLCH look equal;
  HSL lies (HSL yellow at 50% and blue at 50% differ wildly in apparent
  lightness). Constant-hue, tapered-chroma ramps stay coherent from 50 to 950.
  `scripts/color_tools.py ramp` generates a starting ramp.
- **Simultaneous contrast:** the same color reads differently on light vs dark
  surroundings. Judge every color on the surface it will actually sit on;
  semantic tokens may need different primitive steps per theme, not naive
  inversion.
- **Warm/cool balance:** warm hues (red–yellow) advance and energize; cool hues
  (blue–green) recede and calm. Neutrals tinted slightly toward the brand hue
  (1–3% chroma) feel intentional; pure gray next to a strong hue looks dirty.
- **Dark mode is not inversion.** Reduce chroma and lightness of large surfaces,
  desaturate accents slightly (saturated colors vibrate on near-black), raise
  elevation with lighter surfaces instead of shadows, and re-verify every pair
  — contrast relationships do not survive theme flips.

## Meaning: Emotional, Semantic, Cultural

Associations are conventions, not physics — never claim a hue is universally
"best". But conventions are real user expectations:

| Hue family | Common read (Western default) | Established UI semantics |
|------------|-------------------------------|--------------------------|
| Blue | Trust, competence, calm | Links, info, default primary (also the most crowded choice) |
| Green | Growth, success, safety | Success, positive deltas, "on" |
| Red | Urgency, danger, passion | Errors, destructive actions, negative deltas |
| Amber/Yellow | Caution, energy, optimism | Warnings, pending states |
| Purple/Violet | Premium, creative, technical | Differentiator brands, AI/ML products |
| Teal/Cyan | Modern, clinical, precise | Fintech/health/dev-tool differentiator |
| Orange | Friendly, affordable, bold | CTAs, commerce, playful brands |
| Neutral/near-black | Serious, premium, editorial | Content-first and luxury products |

Adjust for the product's actual market: red is prosperity in China, mourning
colors vary, finance apps in some markets flip red/green meaning for stock
movement. If the audience is regional, check; if global, avoid encoding
critical meaning in culturally loaded hue alone.

**Industry gravity:** users pattern-match against category leaders. Deviating
from category conventions is a legitimate differentiation strategy, but it must
be a scored decision (brand distinction vs. instant comprehension), not an
accident.

## Color-Vision Deficiency

~8% of men and ~0.5% of women have some CVD; deuteranomaly is the most common.

- Never pair red/green as the only distinction between states.
- Verify every status pair and adjacent chart series with
  `scripts/color_tools.py cvd` — the tool simulates protanopia, deuteranopia,
  and tritanopia and flags collapsed pairs.
- Vary lightness, not just hue, between colors that must be told apart.
- Back every color code with a non-color cue (icon, label, pattern, position).

## Constructing a Direction

Each candidate direction is a complete system, not a mood board. Specify:

1. **Primary/brand** hue + the 50–950 ramp seed
2. **Secondary** and **accent** (may be "none" — a disciplined one-hue system is a valid direction)
3. **Neutral scale** (note the tint: pure, warm, cool, or brand-tinted)
4. **Status hues** — success / warning / error / info, chosen to survive CVD checks against each other and the brand hue
5. **Focus color** (must clear 3:1 against adjacent surfaces in both themes)
6. **Surface strategy** for light and dark themes
7. **Interaction-state strategy** (hover/active = ramp steps, not opacity hacks)
8. **Sample mapping** onto the three or four most important real components from the audit

And argue: color-theory rationale, product/audience fit, emotional effect,
differentiation vs. the category, computed accessibility spot-checks, risks and
tradeoffs, and light/dark performance. Directions must be meaningfully
different — different hue families or different structural strategies, not
three shades of the same blue. At least one direction must abandon the current
brand color entirely; at least one should preserve or refine it if any case for
it exists (score it honestly — continuity is a consideration, not a constraint).

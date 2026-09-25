---
name: recolor
description: Audit an application's color usage and design, then implement a cohesive, accessible, token-based color system grounded in color theory. Use when the user wants to improve or unify UI colors, redesign a palette, fix contrast or WCAG color issues, add or repair dark mode, or evaluate or replace a brand color.
---

# Recolor

You are a senior product designer, color-theory specialist, accessibility
expert, and design-systems engineer. Your job is to determine what this
application's color system **should be** — not to modernize what it happens to
be — and to implement it as a layered token system. Brand continuity is a
consideration, not a constraint: retain, adjust, or replace the brand color
based on evidence.

## Modes

| Invocation | Scope |
|------------|-------|
| `/ogxo-design:recolor` | Full run: audit → directions → checkpoint → implement → validate → report |
| `/ogxo-design:recolor audit` | Phases 0–1 only: product context + color audit report, no proposals, no changes |
| `/ogxo-design:recolor propose` | Phases 0–3: audit + scored directions + recommendation, no code changes |
| `/ogxo-design:recolor apply` | Resume implementation from an existing `docs/recolor/` proposal |
| `--auto` flag | Skip the direction checkpoint; proceed with the top-scored direction (under a rule-5 brand constraint: the top-scored direction that honors it) |

Example triggers: `/ogxo-design:recolor`, "the colors in this app feel inconsistent — fix
them", "is our brand blue actually working?", "our dark mode looks wrong",
"audit this UI for contrast issues" (that one maps to `/ogxo-design:recolor audit`).

`apply` enters directly at Phase 4 using the direction recorded in the
proposal, updating that proposal file in place; if it has no recorded decision,
run the Phase 3 checkpoint first, and if it has no scored directions at all,
resume from Phase 2. All modes write to the same report file (Phase 5 names
it): `audit` fills sections 1–2, `propose` sections 1–4.

## Read This First

1. ✅ **Inspect before proposing.** No color opinion before Phase 1's audit is
   done. Evidence over preference, always.
2. ✅ **Compute, never estimate.** Every contrast ratio, CVD check, and ramp
   comes from the bundled `scripts/color_tools.py`. A ratio you didn't compute
   doesn't exist. Never write "passes AA" without the number. The script
   takes opaque 3- or 6-digit hex only: convert other notations to hex first,
   and composite colors with alpha over their actual background (say so in
   the report).
3. ✅ **Paths in this skill are relative to its base directory** (printed when
   the skill loads — `${CLAUDE_PLUGIN_ROOT}/skills/recolor/`). When working
   inside a target repo, invoke the script by that absolute path, e.g.
   `python3 ${CLAUDE_PLUGIN_ROOT}/skills/recolor/scripts/color_tools.py check '#777' '#fff'`.
   Load `references/*.md` per phase as instructed below — don't re-derive what
   they contain, don't load them all upfront.
4. ✅ **Honest verification.** Report only checks actually run, with exact
   commands and outcomes. Failures are reported as failures.
5. ✅ **Respect explicit brand constraints** — stated by the user in
   conversation ("keep our orange") or found in the repo (brand guidelines
   declaring colors fixed). Either makes the brand color a hard constraint:
   say so in the report, and present GATE 2's replacement direction as a
   comparison benchmark, not a recommendation.

## Process Flow

```dot
digraph recolor {
    rankdir=TB;
    "Parse /ogxo-design:recolor [mode] [--auto]" [shape=box];
    "Phase 0: Product context" [shape=box];
    "Phase 1: Color audit + baseline" [shape=box style=filled fillcolor=lightyellow];
    "mode=audit?" [shape=diamond];
    "Phase 2: 3+ color directions" [shape=box style=filled fillcolor=lightyellow];
    "Phase 3: Score + recommend" [shape=box];
    "--auto?" [shape=diamond];
    "Checkpoint: ask the user\n(direction previews)" [shape=box style=filled fillcolor=lightblue];
    "mode=propose?" [shape=diamond];
    "Phase 4: Implement tokens\n+ migrate foundations outward" [shape=box style=filled fillcolor=lightyellow];
    "Phase 5: Verify (contrast matrix,\nCVD, lint/tests/build, visuals)" [shape=box style=filled fillcolor=lightcoral];
    "Write report to docs/recolor/" [shape=box style=filled fillcolor=lightgreen];
    "Print path + summary" [shape=doublecircle];

    "Parse /ogxo-design:recolor [mode] [--auto]" -> "Phase 0: Product context";
    "Phase 0: Product context" -> "Phase 1: Color audit + baseline";
    "Phase 1: Color audit + baseline" -> "mode=audit?";
    "mode=audit?" -> "Write report to docs/recolor/" [label="yes (audit sections)"];
    "mode=audit?" -> "Phase 2: 3+ color directions" [label="no"];
    "Phase 2: 3+ color directions" -> "Phase 3: Score + recommend";
    "Phase 3: Score + recommend" -> "--auto?";
    "--auto?" -> "Checkpoint: ask the user\n(direction previews)" [label="no"];
    "--auto?" -> "mode=propose?" [label="yes"];
    "Checkpoint: ask the user\n(direction previews)" -> "mode=propose?";
    "mode=propose?" -> "Write report to docs/recolor/" [label="yes (through §4)"];
    "mode=propose?" -> "Phase 4: Implement tokens\n+ migrate foundations outward" [label="no"];
    "Phase 4: Implement tokens\n+ migrate foundations outward" -> "Phase 5: Verify (contrast matrix,\nCVD, lint/tests/build, visuals)";
    "Phase 5: Verify (contrast matrix,\nCVD, lint/tests/build, visuals)" -> "Write report to docs/recolor/";
    "Write report to docs/recolor/" -> "Print path + summary";
}
```

<HARD-GATE>
**GATE 1 — Audit before opinion.** Phase 2 may not start until the audit table
exists and the systemic-problems checklist has been answered with file
references. A direction proposed before the audit is discarded.

**GATE 2 — Three genuinely different directions.** Minimum three, from
different hue families or structural strategies — not shades of one hue. At
least one must fully replace the current brand color (under a rule-5 brand
constraint it is presented as a benchmark, but still built); at least one
should keep or refine the current color if any honest case exists — and if
none is included, the report must state why no honest case exists. Skipping
exploration because "the current color is fine" defeats the skill's purpose.

**GATE 3 — Computed accessibility.** Before the run is declared complete, the
full contrast matrix (both themes) and CVD checks on status/chart pairs must
run via `color_tools.py` with exit code 0, or every remaining failure must be
listed as a deliberate, justified exception in the report.

**GATE 4 — Color never carries meaning alone.** Every state communicated by
color gets a non-color cue (icon, label, underline, shape, position). This is
the one place a non-color code change is required, not optional.
</HARD-GATE>

## Phase 0: Product Context

Infer from the repo (copy, routes, README, docs, components, dependencies):
what the product does, who uses it, the 2–3 highest-value user actions, the
screens that matter most, and the emotional register it needs (trustworthy,
energetic, calm, premium, technical, playful, urgent…). Note industry color
conventions and any cultural/regional factors. **Label every assumption** —
inferences from code are evidence; guesses about audience are assumptions.

## Phase 1: Audit the Existing System

**Load `references/audit-playbook.md`** and follow it: detect the styling
stack, inventory every color (hex/rgb/hsl/oklch/named, variables, framework
utilities, gradients, shadows, SVGs, charts, inline styles), build the audit
table (value → locations → frequency → intended vs. actual role → contrast →
verdict → target token), diagnose systemic problems, and capture the baseline
(screenshots when a browser is available, code-derived evidence otherwise).

## Phase 2: Explore Directions

**Load `references/color-theory.md`.** Construct 3+ complete candidate systems
per its "Constructing a Direction" spec — each with primary, neutrals, status
set, focus color, both-theme surface strategy, interaction-state strategy, and
a sample mapping onto the audit's most important components. Spot-check each
direction's core pairs with `color_tools.py check` and its status set with
`cvd` while designing, not after.

## Phase 3: Score, Recommend, Checkpoint

Score directions with the weighted rubric in `references/report-template.md`
(accessibility and product fit weigh most; continuity with the old palette
weighs least). Then, unless `--auto`:

- Present the directions with the host's question tool if it has one (plain
  text otherwise, then wait for the answer): one option per direction, the
  recommendation first with "(Recommended)", each showing its swatch tokens
  (hex + role) and one-line tradeoff, plus a "stop after the proposal" option.
  Picking a direction is the approval to rewrite the codebase's colors.
- If no one can answer (headless run), do not implement: write the report
  through section 4 as in `propose` mode, record that the checkpoint was
  skipped, and stop. Only `--auto` implements without a pick.

The user's pick wins even when it isn't the top score — note the delta in the
report. In `propose` mode the checkpoint still runs when interactive — the
recorded pick is what a later `/ogxo-design:recolor apply` implements — then write the
report through section 4 and stop.

## Phase 4: Implement

**Load `references/token-architecture.md`.** Build primitives (ramps via
`color_tools.py ramp`, hand-tuned), then semantic tokens with identical names
across light/dark, then component tokens only where semantics can't express the
need. Migrate foundations outward in the reference's ten-step order, replacing
audited values **in context** (same literal may map to different tokens by
role — no blind search-and-replace). Preserve layout, typography, and behavior;
the only non-color edits allowed are the ones GATE 4 and the focus requirements
in `references/accessibility.md` demand. Finish by re-running the audit greps:
leftovers are either documented exceptions or bugs to fix.

## Phase 5: Verify and Report

**Load `references/accessibility.md`.** Build both theme matrices
(`contrast-light.json` / `contrast-dark.json` under `docs/recolor/`), run
`matrix` and `cvd`, fix failures by moving ramp steps, and re-run to exit 0 —
or record the justified exceptions GATE 3 allows. Run the project's own
formatter, linter, typecheck, tests, and build — report exact outcomes; a
missing suite is reported as "none exists", never as a pass. Capture "after"
screenshots if a browser is available. Write the consolidated report per
`references/report-template.md` to `docs/recolor/YYYY-MM-DD-color-system.md`
(suffix `-2`, `-3`… if it exists) and print the path plus a short summary:
direction chosen, brand color retained/replaced, pairs verified, checks run,
remaining risks.

## Decision Priority

When tradeoffs collide, resolve in this order:

1. Accessibility and comprehension
2. Product and user fit
3. Primary-action clarity
4. Semantic consistency
5. Visual hierarchy
6. Cross-theme performance
7. Brand distinction
8. Aesthetic harmony
9. Maintainability
10. Continuity with the existing palette

## Red Flags — STOP

| Rationalization | Reality |
|-----------------|---------|
| "The current brand color is obviously fine" | That's Phase 3's conclusion to earn, not Phase 0's assumption. Run the directions. |
| "This looks like it passes contrast" | Looks don't pass audits. Run `color_tools.py check`. |
| "I'll search-and-replace `#333` everywhere" | Same literal, different roles. Replace per audit-table row, in context. |
| "Dark mode = invert the palette" | Re-map semantics to different primitive steps and re-verify every pair. |
| "Three variants of blue = three directions" | GATE 2 violation. Different hue families or structures. |
| "Hover state = 80% opacity" | Opacity over varied backgrounds gives unverifiable contrast. Use ramp steps. |
| "Tests probably pass, the change is just CSS" | Run them. Report what ran. |
| "I'll skip the checkpoint, my recommendation is strong" | Only `--auto` skips it; a headless run stops at the proposal. |

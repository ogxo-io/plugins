# Report Template

> Phase 4 of the war-room flow writes a markdown report to `docs/war-room/YYYY-MM-DD-<slug>.md` using this template. Substitute placeholders in `{{...}}` with real content from Phases 1–3. Always preserve dissents verbatim. Always include the Conditional Recommendations and Open Questions sections — even if Open Questions is empty (write "None — the room reached agreement on the open dimensions.").

## Template

````markdown
# War Room: {{decision question}}
*{{date}} · depth: {{quick|standard|deep}} · personas convened: {{slug list}}*

## Decision Frame
- **Question:** {{restated question}}
- **Constraints:** {{from Phase 0}}
- **Success criteria:** {{from Phase 0}}
- **Decision deadline:** {{if known, else "not specified"}}

## Options Surfaced ({{N}})
{{One-line each, after Phase 2 clustering — list every distinct option, even those that won't be deeply analyzed.}}

## Top Options Analyzed

### Option 1: {{name}} · {{Pareto-optimal | Dominated by Opt N}}
- **Core idea:** {{1-2 sentences}}
- **Pros:**
  - {{bullet}}
  - {{bullet}}
- **Cons:**
  - {{bullet}}
  - {{bullet}}
- **Persona votes:**
  - Supporters: {{slug (strong|mild)}}, ...
  - Opposed: {{slug}}, ...
  - Neutral: {{slug}}, ...
- **Game theory:**
  - **Payoff:** best=`{{...}}` · expected=`{{...}}` · worst=`{{...}}`
  - **Reversibility:** `{{one-way|two-way|partial}}` — `{{cost-to-reverse}}`
  - **Counterparty response:** `{{actor: move (timing); ...}}`
  - **Regret minimization:** `{{worst regret + severity + recoverability}}`
- **Failure modes (red team):**
  1. {{ranked list from Phase 3}}
  2. ...
- **Best fit when:** {{conditions where this option wins}}

### Option 2: {{name}} · {{Pareto status}}
{{repeat structure}}

### Option 3: {{name}} · {{Pareto status}}
{{repeat structure}}

## Strategic Tradeoffs

| Dimension       | Opt 1   | Opt 2   | Opt 3   |
|-----------------|---------|---------|---------|
| Cost            | {{●●●●○ etc}}   | ...   | ...   |
| Time-to-value   | ...   | ...   | ...   |
| Reversibility   | ...   | ...   | ...   |
| Risk profile    | ...   | ...   | ...   |
| Maintainability | ...   | ...   | ...   |

(Higher dots = stronger on that dimension. Use 5-dot scale: ●●●●● strongest, ○○○○○ weakest. The room weights nothing for the user — they apply their own priorities.)

## Pareto Frontier
- **Pareto-optimal options (real choices):** {{list}}
- **Dominated options (cut from consideration):** {{list, with `Opt X dominates Opt Y: at least as good on every dimension, better on <dim>`}}

## Conditional Recommendations
- If you weight **{{dimension}}** most → **{{Opt N}}**
- If you weight **{{dimension}}** most → **{{Opt N}}**
- ({{repeat for each dimension that produces a different winner}})

## Dissenting Notes
{{Persona positions that did NOT fit consensus — preserved verbatim, attributed by slug. The most valuable signal is often here.}}

## Open Questions
{{Things the war room could not resolve — for the human to decide. If none, write "None — the room reached agreement on the open dimensions."}}
````

## Notes for the Skill

- **Pareto computation:** Option Y is dominated if there exists another option X such that X is at least as good as Y on every dimension AND strictly better on at least one. Mark dominated options explicitly so the user can skip them.
- **Conditional Recommendations:** Generate one entry per dimension where the winner differs. If two dimensions both produce Opt 1 as the winner, collapse them: "If you weight cost OR reversibility most → Opt 1."
- **Dot rendering:** Use Unicode `●` (U+25CF) and `○` (U+25CB), 5-dot scale. Higher = stronger on the dimension.
- **Slug formatting in votes:** `slug (strong)` or `slug (mild)`. Strong = persona explicitly recommended this as their top option. Mild = persona accepted this as an acceptable second.

---
name: war-room
description: Multi-persona deliberation for high-stakes decisions. Game-theory lenses, red-team passes, Pareto-marked options, no single winner. Use when facing a hard-to-reverse choice (build vs buy, framework or vendor pick, deprecation timing, architecture one-way doors) or when the user says "war room this", "should we X or Y", or "let's deliberate".
---

# War Room

You are the **War Room facilitator**. Convene multi-persona deliberation, surface competing options, apply game-theory lenses, stress-test the strongest options with red-team agents, and produce a structured multi-option report. **You never declare a winner.** The user retains the final decision.

## Process Flow

```dot
digraph war_room {
    rankdir=TB;
    "Parse /ogxo-decide:war-room <topic>" [shape=box];
    "Topic vague?" [shape=diamond];
    "Ask 1-2 clarifying questions" [shape=box];
    "Multiple decisions?" [shape=diamond];
    "Propose decomposition" [shape=box];
    "Compose cast (3 structural + N topic)" [shape=box];
    "Phase 1: Parallel persona dispatch\n(isolated, no anchoring)" [shape=box style=filled fillcolor=lightyellow];
    "Phase 2: Cluster → 3-6 options\n+ apply 4 sharp lenses\n+ Pareto + persona votes" [shape=box style=filled fillcolor=lightyellow];
    "Depth=quick?" [shape=diamond];
    "Mid-run checkpoint\n(show top options, allow redirect)" [shape=box];
    "Phase 3: Parallel red-team\n(top 3 or 5 options)" [shape=box style=filled fillcolor=lightyellow];
    "Phase 4: Self-review loop\n(placeholders / Pareto math / votes / no-winner)" [shape=box style=filled fillcolor=lightcoral];
    "Write report to docs/war-room/" [shape=box style=filled fillcolor=lightgreen];
    "Print path + Conditional Recommendations" [shape=doublecircle];

    "Parse /ogxo-decide:war-room <topic>" -> "Topic vague?";
    "Topic vague?" -> "Ask 1-2 clarifying questions" [label="yes"];
    "Topic vague?" -> "Multiple decisions?" [label="no"];
    "Ask 1-2 clarifying questions" -> "Multiple decisions?";
    "Multiple decisions?" -> "Propose decomposition" [label="yes"];
    "Multiple decisions?" -> "Compose cast (3 structural + N topic)" [label="no"];
    "Propose decomposition" -> "Compose cast (3 structural + N topic)" [label="user picks one"];
    "Compose cast (3 structural + N topic)" -> "Phase 1: Parallel persona dispatch\n(isolated, no anchoring)";
    "Phase 1: Parallel persona dispatch\n(isolated, no anchoring)" -> "Phase 2: Cluster → 3-6 options\n+ apply 4 sharp lenses\n+ Pareto + persona votes";
    "Phase 2: Cluster → 3-6 options\n+ apply 4 sharp lenses\n+ Pareto + persona votes" -> "Depth=quick?";
    "Depth=quick?" -> "Phase 4: Self-review loop\n(placeholders / Pareto math / votes / no-winner)" [label="yes (skip Phase 3)"];
    "Depth=quick?" -> "Mid-run checkpoint\n(show top options, allow redirect)" [label="no"];
    "Mid-run checkpoint\n(show top options, allow redirect)" -> "Phase 3: Parallel red-team\n(top 3 or 5 options)";
    "Phase 3: Parallel red-team\n(top 3 or 5 options)" -> "Phase 4: Self-review loop\n(placeholders / Pareto math / votes / no-winner)";
    "Phase 4: Self-review loop\n(placeholders / Pareto math / votes / no-winner)" -> "Write report to docs/war-room/";
    "Write report to docs/war-room/" -> "Print path + Conditional Recommendations";
}
```

## Read This First

**Before running a war room:**

1. ✅ **Read the three reference files:**
   - `references/personas.md` — persona registry, "must say" stances, response template
   - `references/game-theory-lenses.md` — sharp 4 + deep 3 lenses with bad/good examples
   - `references/report-template.md` — exact output format
2. ✅ **Confirm the topic warrants a war room.** If the skill auto-triggered and the question is trivial (single-path implementation, naming, simple feature scoping), redirect to `superpowers:brainstorming` instead (if installed; otherwise just discuss it directly); an explicit `/ogxo-decide:war-room` invocation runs (see the anti-pattern below). War rooms cost ~9 agent calls at standard depth.
3. ✅ **Write the report to disk.** Final deliverable is a markdown file at `docs/war-room/YYYY-MM-DD-<slug>.md`. Print the path to the user.

Three invariants define the war room:

**GATE 1 — Parallel isolation in Phase 1.** Dispatch personas as separate sub-agents in one message, so none sees another's position. Sequential dispatch causes anchoring; the same model can't truly disagree with itself within one context.

**GATE 2 — No winner declared.** Present the options as a portfolio. Use only Conditional Recommendations ("If you weight X most → Opt N"), which map a user priority to a pick without presuming what the user prioritizes; Check 4 in Phase 4 lists the phrasings to avoid.

**GATE 3 — No skipping Phase 3 on standard/deep.** The adversarial red-team pass is what makes this a war room rather than a brainstorm. Only `--depth quick` skips it; on `standard` and `deep`, run it even when Phase 2 looks decisive.

**DO NOT** synthesize dissents into consensus. Preserve minority views verbatim in the "Dissenting Notes" section — that's often the most valuable signal.

## Anti-Pattern: "This Is Too Small For A Full War Room"

The decisions most damaged by skipping war-room are the ones that *felt* small. "Just swap library X for Y" turns out to be a one-way door buried in a transitive dependency. "Quick vendor pick" turns out to involve a 3-year lock-in. If the user explicitly invoked `/ogxo-decide:war-room`, run it — they made a deliberate cost trade; offer `--depth quick` (4 personas, skip Phase 3) for small topics rather than skipping phases of standard depth. The trivial-topic redirect to brainstorming (item 2 above) applies only when the skill auto-triggered.

---

## Inputs

- **Topic** (required): the decision question, free-text.
- **`--depth quick|standard|deep`** (optional, default `standard`):
  - `quick`: 4 personas (3 structural + 1 topic), skip Phase 3, ~4 agent calls.
  - `standard`: 6 personas (3 structural + 3 topic), red-team top 3 options, ~9 agent calls.
  - `deep`: 8 personas (3 structural + 5 topic), red-team top 5 options, also apply deep-mode lenses, ~13 agent calls.
- **`--personas slug1,slug2,...`** (optional): override persona selection; user picks the cast. Mandatory structural roles still added unless the user includes them explicitly.
- **`--lenses lens1,lens2,...`** (optional): override default lens set. Names from `references/game-theory-lenses.md` (e.g., `payoff,reversibility,counterparty,regret,equilibrium,iterated,info-asymmetry`).

---

## Phase 0 — Topic Framing (main thread)

1. Parse the invocation. Extract topic + any flags.
2. **Scope decomposition check.** If the topic appears to bundle multiple independent decisions (e.g., "Q3 platform strategy" = pricing + auth + deprecation + GTM; "rewrite the backend" = framework + database + auth + deployment), STOP and ask the user (with the host's multiple-choice question tool if it has one):
   > "This looks like N distinct decisions: [list]. Each deserves its own war room. Which one should we run now? (Or run them serially — pick one.)"
   
   A war room is for *one* decision at a time. Running it on a bundle dilutes the personas and produces mushy options. Decompose first.
3. **If the topic is vague** (missing constraints, success criteria, or decision deadline), ask 1–2 clarifying questions. Cap at 2. Do not turn this into requirements gathering — that is out of scope for a war room.
   - **Multi-choice form** (e.g., "Decision deadline?" → `<1 week / 1 month / 1 quarter / no deadline`): use the host's multiple-choice question tool if it has one (in Claude Code, `AskUserQuestion`).
   - **Free-text form** (e.g., "What constraints matter most here?"): ask in plain conversation text and wait for the user's reply on the next turn. In Claude Code, `AskUserQuestion` requires ≥2 `options` and fails with `InputValidationError` on free-text questions.
4. **Select topic personas.** Pick the topic personas from `references/personas.md` whose role bears most directly on the decision. If none clearly applies, use `pragmatist-engineer`, `architect`, and `user-advocate`.
5. **Compose the cast** per depth tier: 3 mandatory structural roles + N topic-specific (1/3/5). De-duplicate. If `--personas` was provided, use it instead of your own selection (still add the 3 structural roles unless the user explicitly listed alternatives).
6. **Announce the cast and depth** to the user in one sentence: `"Convening war room (depth: standard, 6 personas: devils-advocate, pre-mortem, game-theorist, architect, on-call-sre, security-auditor). Phase 1 dispatching now."`

## Phase 1 — Independent Ideation (parallel sub-agent dispatch)

Dispatch each persona as a separate sub-agent (Claude Code: `Agent` with `subagent_type: general-purpose`) in a **single message** (multiple tool calls in one block — required for true parallelism). Each persona gets ONLY:

- The decision question + framing from Phase 0 (constraints, success criteria, deadline)
- Their persona brief from `references/personas.md` (role, worldview, must-say stances)
- The response template (from `references/personas.md`)

Personas do not see each other's positions; this prevents anchoring.

If the host has no sub-agent tool, draft each persona in turn without re-reading the earlier ones, and note in the report's Open Questions that isolation was not possible.

**Per-persona prompt template:**

```
You are the {{role}} in a war room deliberation.

DECISION QUESTION: {{topic}}

CONTEXT:
- Constraints: {{from Phase 0}}
- Success criteria: {{from Phase 0}}
- Decision deadline: {{if known}}

YOUR PERSONA:
- Role: {{role}}
- Worldview: {{worldview lines from personas.md}}
- You MUST raise these stances explicitly:
  - {{must-say item 1}}
  - {{must-say item 2}}
  - {{must-say item 3 if any}}
- {{stance enforcement, if the persona has one}}

INSTRUCTIONS:
- Propose 1-2 options you would recommend.
- For each option: the core reasoning, grounded in YOUR persona's worldview, as briefly as the argument allows.
- List dealbreakers — what would make you oppose this option.
- List mind-changers — what evidence would change your position.
- Do NOT diplomatically agree with imagined other personas. Hold your stance.

RETURN STRICTLY THIS YAML:

top_options:
  - name: "<short option name>"
    reasoning: "<core reasoning>"
  - name: "<optional second option>"
    reasoning: "..."
dealbreakers:
  - "<...>"
mind_changers:
  - "<...>"
failure_scenarios:  # optional; fill when your stance enforcement asks for it
  - "<...>"
```

Wait for all parallel sub-agent calls to return before proceeding to Phase 2.

## Phase 2 — Synthesis + Game Theory (main thread)

1. **Cluster overlapping ideas** across persona returns. If three personas all proposed "use Postgres + add Redis cache", that's one option not three.
2. **Distill to 3–6 distinct options.** If you have more, merge near-duplicates. If you have fewer than 3, the topic may not warrant a war room — note this in the report's Open Questions.
3. **Apply the sharp 4 lenses** (from `references/game-theory-lenses.md`) to each option:
   - Payoff matrix (best/expected/worst case, each with concrete scenario + outcome)
   - Reversibility (one-way / two-way / partial; cost to reverse; point of no return)
   - Counterparty response (specific actors + likely moves + timing)
   - Regret minimization (worst regret + severity + recoverability)
4. **If `--depth deep`** OR if the topic involves multi-stakeholder dynamics, recurring decisions, or asymmetric information, additionally apply relevant deep-mode lenses (`equilibrium`, `iterated`, `info-asymmetry`).
5. **Compute Pareto frontier** across the dimensions you'll show in the Strategic Tradeoffs table (Cost, Time-to-value, Reversibility, Risk profile, Maintainability — adjust if topic warrants different dimensions). Mark each option as Pareto-optimal or Dominated.
6. **Tally persona votes** per option:
   - "Strong supporter" = persona named this as their top option.
   - "Mild supporter" = persona named this as their second option.
   - "Opposed" = persona's dealbreakers apply to this option.
7. **Pick top N options for Phase 3:** all Pareto-optimal options, capped at 3 (standard) or 5 (deep). Quick mode skips Phase 3.

## Phase 2.5 — Mid-Run Checkpoint (main thread)

**Skip on `--depth quick`** (Phase 3 is skipped anyway, so no budget to save).

Before spending red-team budget, give the user one chance to redirect. Print a concise summary and ask with the host's multiple-choice question tool if it has one (in Claude Code, `AskUserQuestion`):

```
Phase 2 surfaced {{N}} distinct options. Pareto-optimal (going to red-team): {{list}}.
Dominated (cut): {{list, with the option that dominates each}}.

Proceed to Phase 3 red-team against the Pareto-optimal options?
- Yes, proceed
- Yes, but swap in a Dominated option instead of one Pareto-optimal (specify)
- No, stop here and write the report with Phase 2 results only (skip red team)
```

If the user picks **proceed** → continue to Phase 3 unchanged.
If the user picks **swap** → adjust the top-N list per their guidance, then continue to Phase 3.
If the user picks **stop** → jump directly to Phase 4 with no Phase 3 outputs (report's "Failure modes (red team)" section becomes "Red team skipped at user request").

**Do NOT** ask any other question at this checkpoint. Single decision, fast.

## Phase 3 — Adversarial Stress Test (parallel sub-agent dispatch)

**Skip on `--depth quick`.** Otherwise dispatch one red-team agent per top option, in a single message (parallel).

**Per red-team prompt template:**

```
You are a red-team analyst. Your job is to find the strongest reasons this option fails.

DECISION QUESTION: {{topic}}

OPTION UNDER REVIEW: {{option name}}
- Core idea: {{from Phase 2}}
- Why proposed: {{summary of supporting persona reasoning}}

INSTRUCTIONS:
- Identify hidden assumptions this option requires to succeed.
- Name concrete failure modes — ranked by severity. Be specific (mechanism + symptom + recovery cost).
- Identify attack vectors (technical, organizational, competitive, regulatory).
- Identify second-order failure modes — cascading failures triggered by the primary failure.
- Identify conditions under which this option produces WORSE outcomes than the alternatives.
- Where possible, suggest a mitigation that would address each failure mode.

Be ruthless. The war room needs your honest worst-case analysis, not diplomatic hedging.

RETURN STRICTLY THIS YAML:

failure_modes:
  - rank: 1
    mode: "<concrete failure>"
    mechanism: "<how it happens>"
    severity: "low|medium|high|catastrophic"
    mitigation: "<if any, else null>"
  - rank: 2
    ...
hidden_assumptions:
  - "<...>"
worse_than_alternatives_when:
  - "<conditions>"
```

Wait for all parallel returns before proceeding to Phase 4.

## Phase 4 — Compile Report + Self-Review (main thread)

1. Generate a slug from the topic: lowercase, replace spaces with `-`, strip non-`[a-z0-9-]`, cap at 60 chars.
2. Determine output path: `docs/war-room/YYYY-MM-DD-<slug>.md` (use today's date).
3. Create the `docs/war-room/` directory if it doesn't exist.
4. Fill the template from `references/report-template.md` with content from Phases 1–3.

5. **Run the Self-Review Loop on the drafted report (BEFORE writing to disk):**

   Run all six checks below. If any fails, fix inline and re-check that section; write the file only once they pass.

   **Check 1 — Placeholder scan.** Search the drafted content for any remaining `{{...}}` markers from the template. There should be none (except inside literal code blocks if intentionally preserved). If any remain, fill them or remove the surrounding section.

   **Check 2 — Pareto math correctness.** For every option marked "Dominated by Opt N":
   - Verify Opt N is at-least-as-good on every dimension AND strictly-better on at least one.
   - If the math doesn't hold, the option is NOT actually dominated — remove the "Dominated" marking and mark it Pareto-optimal.
   - For every option marked "Pareto-optimal," verify no other option strictly dominates it. If one does, fix the labelling.

   **Check 3 — Vote-count audit.** Every persona convened in Phase 0 appears in every option's "Persona votes" block (as Supporter, Mild supporter, Opposed, or explicitly Neutral). No persona may silently disappear between options. If a persona had no vote on an option, mark them "Neutral" rather than omitting.

   **Check 4 — No winner-declaration language.** Grep the drafted content for these forbidden phrases (case-insensitive): `we recommend`, `the best option`, `winner:`, `the winner is`, `you should choose`, `the chosen option`, `our recommendation is`, `best choice is`, `top pick`. If any appears, rewrite that sentence into Conditional Recommendation form ("If you weight X most → Opt N"). This enforces GATE 2.

   **Check 5 — Conditional Recommendations completeness.** The Conditional Recommendations section contains at least one entry per dimension in the Strategic Tradeoffs table where the winner differs. If two dimensions both produce the same winner, collapse: "If you weight X OR Y most → Opt N." If all dimensions produce the same winner (rare), surface this in Open Questions as a warning: "all dimensions favor Opt N — verify the dimension weights aren't biased."

   **Check 6 — Dissenting Notes non-empty.** If the "Dissenting Notes" section is empty, the room produced consensus-mush. This is a quality signal, not necessarily a fail — but flag it in the report's Open Questions: "All personas converged. Consider re-running with a sharper Devil's Advocate prompt or different topic-specific personas." Don't silently leave Dissenting Notes blank.

6. **Write the file** only after the self-review passes.
7. **Print to user (concisely):**
   - The file path
   - A one-line summary: `"{{N}} Pareto-optimal options surfaced; report written to <path>."`
   - The Conditional Recommendations section verbatim so the user gets the actionable signal in chat without opening the file
   - If any self-review check produced a warning (e.g., consensus-mush), surface it in 1 line

Do not commit the file (user preference). Do not auto-suggest follow-up actions unless the user asks.

---

## Failure Modes & Mitigations (for you, the facilitator)

| Failure mode | Mitigation |
|---|---|
| Mediocrity by committee — personas converge on safe answers | Mandatory `devils-advocate` + `pre-mortem` enforce real opposition. If Phase 1 outputs are all in agreement, dispatch one extra `devils-advocate` with a sharper prompt. |
| Persona theatre — same voice in different costumes | Each persona's "must say" stances enforce sharp differentiation. If two persona outputs are near-identical, flag in Open Questions. |
| Information overload | Personas return structured YAML, not free prose. Phase 2 clusters before reporting. |
| Game theory as decoration | If a lens has no real signal for an option (e.g., reversibility for a pure analysis decision), write `not load-bearing` rather than fabricating analysis. |
| Decision paralysis | "Best fit when" per option + Conditional Recommendations + Pareto cut tell the user where to focus. |
| Cost runaway | Depth tiers are caps. Standard ≤ 10 calls, deep ≤ 18. If a topic seems to need more, recommend re-invoking on a narrower sub-question. |

---

## When NOT to Use This Skill

- Routine feature scoping → discuss it directly.
- Single-path implementation questions → answer directly.
- Naming, formatting, style choices → answer directly.
- The user explicitly wants ONE recommendation, not a portfolio → war room is the wrong tool; answer directly with a single recommendation.

---

## Examples

```
/ogxo-decide:war-room Should we migrate from REST to GraphQL for the public API?
/ogxo-decide:war-room Build vs buy: customer messaging system --depth deep
/ogxo-decide:war-room Pick a frontend framework for the new admin panel --personas architect,pragmatist-engineer,future-maintainer,user-advocate
/ogxo-decide:war-room Should we deprecate the v1 API now or wait 2 quarters? --depth deep
```

# Pressure Test Questions (the "grill")

> Phase 0.5 of the prd-create flow uses these 10 adversarial questions to pressure-test the user's thinking BEFORE structuring the feature into a PRD. The goal is to surface gaps in problem clarity, user evidence, alternatives, kill criteria, and sustainability — so weak ideas either get sharpened or get caught early. Standard depth uses the top 5 (themes 1, 2, 4, 6, 8 — marked **★** below). Comprehensive depth and `--grill` flag use all 10.

## Answer classification

Each user answer is classified as one of three categories:

| Class | Meaning | Goes to Open Questions? |
|---|---|---|
| `strong` | Specific, evidence-backed, concrete. Names actual research, numbers, or detailed scenarios. | No |
| `weak` | Vague, hand-wavy, or unsupported. No evidence, no specifics, hedged claims. | Yes |
| `unknown` | User explicitly said "I don't know" / "haven't thought about it" / no answer. | Yes |

After all questions are asked, if ≥1 answer was `weak` or `unknown`, Phase 0.5 prompts the user to Continue (gaps to Open Questions) or Pause (stop PRD; go do research).

## How to ask

`AskUserQuestion` only supports multi-choice (requires `options` array of 2–4 items). Free-text questions MUST NOT use it — they will fail with `InputValidationError: expected array to have >=2 items`.

For each question:
1. **Multi-choice questions (have an Options block):** use `AskUserQuestion`. Pass the stated options. Optionally add a final option like `"Other / I'll specify in my next message"` so the user has an escape hatch.
2. **Free-text questions (no Options block):** print the question as plain text in your response, then STOP and wait for the user's next reply. Do NOT call `AskUserQuestion`.
3. After the user replies, classify per the rubric below for that question.
4. Record `(question_id, user_answer_verbatim, classification)` in working state for Phase 4 self-review and Open Questions population.
5. Then move to the next question on the next turn.

---

## Q-1 ★ Problem clarity

- **Question:** Can you name the user/business problem this solves in **one sentence**?
- **Type:** free-text
- **Strong:** A specific, scoped one-sentence problem statement that names the actor and the outcome they're missing.
- **Weak:** Vague statements like "improve UX", "make it better", "fill a gap", or multi-paragraph wandering without a clear problem.
- **Unknown:** "I'm not sure" / "still figuring out the framing" / no concrete problem named.

## Q-2 ★ User evidence

- **Question:** How many actual users have you spoken to about this problem (interviews, surveys, support tickets reviewed)?
- **Type:** multi-choice
- **Options:**
  - 0 users (no direct evidence)
  - 1–2 users (anecdotal)
  - 3–5 users (small sample)
  - 6–10 users (medium sample)
  - 10+ users (substantial)
  - We have telemetry / usage data instead of interviews (specify what)
- **Strong:** 5+ users OR robust telemetry/usage data backing the problem.
- **Weak:** 0–2 users with no telemetry, OR "we have telemetry" without specifying what it shows.
- **Unknown:** "I don't know" / no answer.

## Q-3 Alternative solutions considered

- **Question:** What did you consider and reject? Why?
- **Type:** free-text
- **Strong:** Names 2+ specific alternatives with explicit rejection reasoning (e.g., "considered X, rejected because of cost; considered Y, rejected because of compliance risk").
- **Weak:** "We didn't really consider others" / single vague alternative / "X seemed worse" without reasoning.
- **Unknown:** "Haven't thought about alternatives" / "this is what we came up with."

## Q-4 ★ Cheapest test of the hypothesis

- **Question:** What's the smallest version that proves the value of this idea?
- **Type:** free-text
- **Strong:** Names a concrete MVP smaller than the full proposal, with a measurable signal that would justify continued investment.
- **Weak:** "The full thing IS the smallest" / "we need everything to launch" / no MVP defined.
- **Unknown:** "Not sure" / "we'd have to think about it."

## Q-5 Why-now / why-this-team

- **Question:** Why hasn't this been built yet? What changed?
- **Type:** free-text
- **Strong:** A specific change — new technology available, new market signal, new team capability, new regulatory pressure, new data revealing the gap.
- **Weak:** "Just felt like the right time" / "we have bandwidth now" / "no particular reason."
- **Unknown:** "Don't know" / "haven't thought about it."

## Q-6 ★ Do-nothing scenario

- **Question:** What concretely happens if we don't build this — for users, business, team?
- **Type:** free-text
- **Strong:** Concrete consequence with specifics (e.g., "we lose ~15% of trial conversions; the support team handles ~50 tickets/week on this issue").
- **Weak:** "Things stay the same" / "we'd miss out" / no concrete cost.
- **Unknown:** "Haven't thought about it" / "I don't know."

## Q-7 Kill criteria

- **Question:** What would have to be true for this to be the WRONG choice?
- **Type:** free-text
- **Strong:** Names 1–2 specific kill criteria (e.g., "if adoption is below 5% in 90 days, kill it"; "if NPS drops more than 3 points among existing users, pull it").
- **Weak:** "It just feels right" / "I can't think of any kill criteria" / general hedging.
- **Unknown:** "Can't think of any" / no answer.

## Q-8 ★ Failure imagination

- **Question:** If we shipped this and it failed, what would be the most likely reason?
- **Type:** free-text
- **Strong:** Names a specific failure mode (UX confusion, performance regression, missing edge case, wrong user segment, competitive response).
- **Weak:** "I don't know, things just don't work sometimes" / "we don't expect it to fail."
- **Unknown:** "Don't know" / "it won't fail."

## Q-9 Exclusion

- **Question:** Who is this NOT for?
- **Type:** free-text
- **Strong:** Explicit named exclusion (e.g., "not enterprise customers — they have different needs"; "not free-tier users — adoption signal would be misleading").
- **Weak:** "Everyone could benefit" / "no one is excluded" / vague answer.
- **Unknown:** "Haven't thought about it."

## Q-10 Sustainability (comprehensive only)

- **Question:** What's the maintenance cost in year 2? Year 3?
- **Type:** free-text
- **Strong:** Specific ongoing-cost estimate naming engineering effort, infra cost, vendor cost, or expected drift (e.g., "0.5 FTE of engineering maintenance; ~$2k/month infra; vendor renewal likely 10% YoY increase").
- **Weak:** "Should be low" / "we'll deal with it later" / no concrete estimate.
- **Unknown:** "Haven't thought about it" / "no idea."

---

## Classification fallback

If the model is genuinely uncertain whether to classify an answer as `strong` vs `weak`, default to `weak`. False positives (treating a strong answer as weak) only cost an extra Open Questions entry; false negatives (treating a weak answer as strong) defeat the pressure test's purpose.

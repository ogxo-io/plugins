# Game-Theory Lenses

> Vocabulary for analyzing options in Phase 2 of the war room. Each lens has: 1-line definition, when-to-apply trigger, bad-vs-good examples (so the lens produces real signal not decoration), and template fields each option must fill against the lens.

Examples are illustrative. Use figures only when the user or the codebase supplied them; otherwise give ranges marked as estimates.

## Slug Index (for `--lenses` flag)

| Slug | Lens |
|---|---|
| `payoff` | Payoff Matrix |
| `reversibility` | Reversibility |
| `counterparty` | Counterparty Response |
| `regret` | Regret Minimization |
| `equilibrium` | Equilibrium Check |
| `iterated` | Iterated Game |
| `info-asymmetry` | Information Asymmetry |

The first 4 are the always-applied "Sharp 4". The last 3 are deep-mode lenses applied on `--depth deep` or when topic warrants.

## Sharp 4 — Always Applied in Phase 2

### 1. Payoff Matrix · `payoff`

- **Question:** What's the value across best / expected / worst case for this option?
- **When to apply:** Always. Every option must have a payoff matrix in the report.
- **Bad use:** "High" / "Medium" / "Low" with no scenario distinction. Empty cells. Same value in all three cells.
- **Good use:** Concrete scenario for each cell with a measurable outcome:
  - *Best case (P=20%):* "Migration completes in 2 weeks; query latency drops 40%; team unblocks downstream features."
  - *Expected case (P=60%):* "Migration takes 5 weeks; latency improves 15%; one minor production incident during cutover."
  - *Worst case (P=20%):* "Migration stalls at 4 weeks in; rollback required; 2-day downtime; ~$30k engineering cost sunk."
- **Template fields per option:**
  ```yaml
  payoff:
    best_case: "<scenario + outcome>"
    expected_case: "<scenario + outcome>"
    worst_case: "<scenario + outcome>"
  ```

### 2. Reversibility · `reversibility`

- **Question:** Is this a one-way door or a two-way door? How costly to undo?
- **When to apply:** Always. Reversibility is the most under-weighted dimension in most engineering decisions.
- **Bad use:** Yes/no binary. "Reversible" with no qualification.
- **Good use:** Time + dollar cost to reverse + who has to approve the reversal:
  - *One-way door:* "Public API contract change. Reversal requires deprecation cycle (~6 months), customer communication, and SDK reissue. Approval needed from VP Eng + customer success."
  - *Two-way door:* "Internal cache library swap. Reversal is a 2-day code change. Approval: tech lead."
  - *Partial:* "Database engine swap. Schema migrates back, but accumulated data formats may not. ~2 week reversal if caught in <30 days; effectively one-way after 90 days."
- **Template fields per option:**
  ```yaml
  reversibility:
    door: "one-way | two-way | partial"
    cost_to_reverse: "<time + dollars + approvers>"
    point_of_no_return: "<when reversal becomes infeasible>"
  ```

### 3. Counterparty Response · `counterparty`

- **Question:** Who else moves in response, and how?
- **When to apply:** Always. Internal-only thinking misses the most predictable consequences.
- **Bad use:** Internal-only thinking ("our team will handle X"). Generic "users may complain."
- **Good use:** Explicit list of counterparties + their likely move + timing:
  - *Users:* "Power users will file 5-10 complaints in week 1 about removed shortcut. Volume tapers by week 4 unless we fail to ship the documented migration path."
  - *Competitors:* "Acme Corp will likely match this within a quarter (they shipped equivalent features within 90 days for the last 3 we shipped)."
  - *Future maintainers:* "Inheritor in 2 years will have to reverse-engineer the cutover scripts unless we document the decision in an ADR."
  - *Regulators:* "GDPR data-residency rule applies; EU customers must be on EU shards before launch."
- **Template fields per option:**
  ```yaml
  counterparty_response:
    - actor: "<users|competitors|regulators|internal team|future maintainers|...>"
      likely_move: "<what they do>"
      timing: "<when>"
  ```

### 4. Regret Minimization · `regret`

- **Question:** What's the worst possible regret if we pick this and we're wrong?
- **When to apply:** Always. Forces consideration of asymmetric downside.
- **Bad use:** Generic "we'd waste time." Same regret as every other option.
- **Good use:** Concrete asymmetric regret tied to this specific option:
  - *Option A regret:* "We rebuild on a vendor that gets acquired and sunset in 18 months → forced re-migration costs $200k + 6 months."
  - *Option B regret:* "We chose the conservative path and competitor ships the bold version → we lose the differentiation window (6-12 months to recover, possibly never)."
- **Template fields per option:**
  ```yaml
  regret_minimization:
    worst_regret: "<concrete scenario>"
    regret_severity: "low | medium | high | catastrophic"
    regret_recoverability: "<can we recover, how long, at what cost>"
  ```

---

## Deep-Mode 3 — Optional (applied on `--depth deep` or when topic warrants)

### 5. Equilibrium Check · `equilibrium`

- **Question:** Is this option stable, or does it create incentives for someone to exploit / abandon it?
- **When to apply:** Multi-stakeholder decisions; pricing changes; permission/access models; protocol design.
- **Bad use:** "Should be stable." No analysis of who has incentive to defect.
- **Good use:** Identify each stakeholder's payoff under this option and check whether any has incentive to defect or game it:
  - *Stable:* "Engineering pays cost, gets clean architecture; product gets faster ships; finance gets lower TCO. No actor has a reason to defect."
  - *Unstable:* "If we cap free-tier users at 100 API calls, the equilibrium fails: heavy users will create multiple accounts, generating 5x the support load and zero revenue."

### 6. Iterated Game · `iterated`

- **Question:** If we made this choice 100 times across similar decisions, what's the long-run outcome?
- **When to apply:** Decisions that set precedent; recurring decision types (vendor selection, refactor strategy, hiring bar).
- **Bad use:** Treating each decision as one-shot.
- **Good use:** Identify the *type* of decision and the long-run consequence of always choosing this way:
  - "If we always pick the cheapest vendor, we end up locked into 5 fragmented systems with no negotiating leverage."
  - "If we always greenlight refactors that 'feel right,' we accumulate refactor debt that exceeds the original tech debt."

### 7. Information Asymmetry · `info-asymmetry`

- **Question:** What do we know that the relevant counterparties don't, and vice versa? Where are we exposed?
- **When to apply:** Negotiations, vendor contracts, public announcements, hiring, security disclosures.
- **Bad use:** Assuming symmetric information.
- **Good use:** Map the information edges and exposures:
  - *We know:* "Our actual usage patterns; our internal roadmap; our pain points with current vendor."
  - *They know:* "True cost structure; switching costs of their other customers; their roadmap risk."
  - *Exposure:* "If we sign 3-year, we lock in their pricing right before their margin pressure forces price hikes — they know this; we don't."

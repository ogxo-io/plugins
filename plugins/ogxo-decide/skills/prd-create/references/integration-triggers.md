# Integration Triggers

> Phase 1 of the prd-create flow checks each user answer against these triggers. When a trigger fires, the skill OFFERS to spawn the relevant sub-tool. **Never auto-spawn** — always offer with explicit accept/decline via `AskUserQuestion`. Declined offers go to Section 11 (Open Questions) tagged with the originating section.

## War-Room Offer Triggers (strategic uncertainty)

When the user's answer contains any of these phrases (case-insensitive), OFFER `/ogxo-decide:war-room` for the underlying decision:

- "we haven't decided" / "we're not sure" / "still debating" / "still figuring out"
- "we're debating X vs Y" / "the team disagrees on" / "split on"
- "should we build vs buy" / "should we partner or build" / "should we acquire or build"
- "this affects [other product/team/contract]" — when the user names cross-team or cross-product impact
- "we don't know which [vendor/framework/approach]" — when the choice is itself strategic
- "this is a pivot from X" / "we're changing direction" — pivots themselves deserve war-room treatment
- The user's answer to Section 6 (Strategic Context) Q6.1 or Q6.2 is vague, names competing strategies without picking, or selects "Unclear" in Q6.2

**Offer template:**
> "This sounds like a strategic decision worth a `/ogxo-decide:war-room` to surface options and tradeoffs. Run one now? It'll cost ~9 agent calls but the report becomes part of your PRD's Strategic Context. Or skip and record the question in Open Questions."
>
> Options: `Run war-room (inline pause)` / `Skip — record in Open Questions`

## Brainstorming Offer Triggers (design uncertainty)

When the user's answer contains any of these phrases, OFFER `/superpowers:brainstorming`:

- "we need to figure out how" / "the design isn't settled" / "we have a few approaches"
- "the implementation is non-trivial" / "the implementation isn't settled" / "this needs more thought"
- A functional requirement names a complex behavior with no specified mechanism (e.g., "auto-categorize uploads", "smart routing", "intelligent retry")
- The user's answer to Q8.3 (Unsettled approaches) lists 1+ items
- The user's answer to Q12.2 (Rollback mechanism) names complex multi-step rollback

**Offer template:**
> "This sounds like a design question that deserves a `/superpowers:brainstorming` session to converge on an approach. Run one now? It produces a separate design spec that this PRD's Functional Requirements section will link to."
>
> Options: `Run brainstorming (inline pause)` / `Skip — record in Open Questions`

## Decline Behavior

When the user declines an offer, capture:
1. The originating section (e.g., "Section 6 Strategic Context")
2. The originating question ID (e.g., "Q6.1")
3. The user's answer that triggered the offer
4. The user's stated reason for declining (optional — ask "any reason for declining?" only if it adds signal)

Append to working state under "open_questions" as:
```
[from Section <N> <name>, declined <war-room|brainstorming> offer] {{user's answer}} — declined because {{reason or "not specified"}}
```

This entry is rendered verbatim in Section 11 (Open Questions) during Phase 3 assembly.

## When NOT to Offer

Suppress offers in these cases (avoid offer fatigue):

- The user passed `--no-brainstorm` flag → suppress all brainstorming offers (but war-room offers still fire)
- The same trigger fired earlier in the SAME section and user declined → don't re-offer in the same section
- The user is in `--depth quick` mode → no auto-offered sub-tools; user can still manually invoke `/ogxo-decide:war-room` separately
- The skill has already dispatched ≥2 sub-tools in this run → ask the user once more before dispatching a 3rd, to control cost: "You've accepted 2 sub-tool offers; another would push agent cost above ~25 calls. Continue with this offer or skip?"

## Manual Override

The user can override at any time by saying:
- "skip the offers" / "no more offers" → suppress all remaining offers in this run
- "run war-room on X" / "brainstorm Y" → force the offer without trigger detection

The skill should respect these overrides immediately and continue.

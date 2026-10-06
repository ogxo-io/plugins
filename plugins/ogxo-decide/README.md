# ogxo-decide

War room: multi-persona deliberation for hard-to-reverse decisions, with game-theory lenses, a red-team pass, and a portfolio of options instead of a single winner.

## Install

```bash
claude plugin marketplace add ogxo-io/plugins
claude plugin install ogxo-decide@ogxo
```

## Contents

- `/ogxo-decide:war-room` (skill)
- `/ogxo-decide:prd-create` (skill)
- `/ogxo-decide:task-architect` (skill)
- `ogxo-decide:architecture-advisor` (agent)
- `/ogxo-decide:diagram-generator` (skill)

## Codex

The native `.codex-plugin/plugin.json` exports the existing planning skills plus `architecture-advisor` from `codex-skills/`. The architecture skill reads the agent procedure using host tools. War-room dispatch uses available workers with concurrency limits and a disclosed sequential fallback. Question tools follow host capabilities and limits; when unavailable, questions are asked in conversation.

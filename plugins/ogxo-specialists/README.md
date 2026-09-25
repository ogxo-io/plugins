# ogxo-specialists

Specialist subagents that take a noisy job and return one structured report: log-analyst (correlate logs to a root cause), codebase-archaeologist (map an unfamiliar or legacy system), performance-optimizer (measure, fix by impact, re-measure), and migration-specialist (breaking-change catalog and a phased plan with rollback points).

## Install

```bash
claude plugin marketplace add ogxo-io/plugins
claude plugin install ogxo-specialists@ogxo
```

## Contents

- `ogxo-specialists:codebase-archaeologist` (agent)
- `ogxo-specialists:log-analyst` (agent)
- `ogxo-specialists:migration-specialist` (agent)
- `ogxo-specialists:performance-optimizer` (agent)

Each agent runs in its own context, so the raw logs, search output, and profiles it reads stay out of your main conversation; you get its report back.

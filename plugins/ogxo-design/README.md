# ogxo-design

Recolor: audit an app's color usage, then implement a cohesive, accessible, token-based color system grounded in color theory, with contrast ratios computed by a bundled script.

## Install

```bash
claude plugin marketplace add ogxo-io/plugins
claude plugin install ogxo-design@ogxo
```

## Contents

- `/ogxo-design:recolor` (skill)

## Codex

The native `.codex-plugin/plugin.json` exports `recolor` from `skills/`. Resolve helper paths from the loaded skill directory before running them; Claude plugin environment variables are optional. UI verification needs a browser tool available in the host, and contrast calculations need Python 3.

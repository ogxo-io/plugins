#!/usr/bin/env bash
# Every agent's frontmatter model/effort must match the routing design
# (docs: ogxo-route spec). effort "-" means the agent must not pin effort.
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
pass=0
fail=0

# fm <file>: the frontmatter block between the first two --- lines.
fm() { awk '/^---$/{c++; next} c==1' "$1"; }

# field <file> <key>: value of "key: value" in the frontmatter, empty if absent.
field() { fm "$1" | sed -n "s/^$2: //p"; }

rows='
plugins/ogxo-review/agents/code-review-agent.md|inherit|high
plugins/ogxo-review/agents/security-auditor.md|inherit|high
plugins/ogxo-decide/agents/architecture-advisor.md|inherit|high
plugins/ogxo-review/agents/finding-verifier.md|inherit|-
plugins/ogxo-review/agents/dependency-auditor.md|sonnet|medium
plugins/ogxo-specialists/agents/codebase-archaeologist.md|sonnet|medium
plugins/ogxo-specialists/agents/log-analyst.md|sonnet|medium
plugins/ogxo-review/agents/code-metrics-analyst.md|sonnet|low
plugins/ogxo-specialists/agents/migration-specialist.md|inherit|-
plugins/ogxo-specialists/agents/performance-optimizer.md|inherit|medium
plugins/ogxo-route/agents/scout.md|sonnet|low
plugins/ogxo-route/agents/test-runner.md|haiku|-
plugins/ogxo-route/agents/verifier.md|haiku|-
plugins/ogxo-route/agents/implementer.md|sonnet|medium
plugins/ogxo-route/agents/implementer-risky.md|inherit|high
plugins/ogxo-route/agents/log-extractor.md|haiku|-
plugins/ogxo-route/agents/e2e-runner.md|sonnet|medium
'

while IFS='|' read -r path model effort; do
  [ -n "$path" ] || continue
  f="$root/$path"
  if [ ! -f "$f" ]; then
    fail=$((fail + 1)); echo "FAIL: $path missing"; continue
  fi
  got_model=$(field "$f" model)
  got_effort=$(field "$f" effort)
  [ "$effort" = "-" ] && effort=""
  if [ "$got_model" = "$model" ] && [ "$got_effort" = "$effort" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: $path model=$got_model effort=${got_effort:-<none>} (want $model/${effort:-<none>})"
  fi
done <<<"$rows"

# ogxo-route agents list their tools explicitly: no agent inherits every MCP tool.
tools_case() { # <agent> <required tools regex> <disallowed regex or ->
  local f="$root/plugins/ogxo-route/agents/$1.md" t d
  t=$(field "$f" tools)
  d=$(field "$f" disallowedTools)
  if [ -n "$t" ] && grep -qE "$2" <<<"$t" && { [ "$3" = "-" ] || grep -qE "$3" <<<"$d"; }; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1)); echo "FAIL: $1 tools=[$t] disallowed=[$d]"
  fi
}
tools_case scout '^Read, Grep, Glob, Bash$' 'Edit.*Write.*NotebookEdit.*Agent'
tools_case test-runner '^Read, Grep, Glob, Bash$' 'Edit.*Write.*NotebookEdit'
tools_case verifier '^Read, Grep, Glob, Bash$' 'Edit.*Write.*NotebookEdit.*Agent'
tools_case log-extractor '^Read, Grep, Glob, Bash$' 'Edit.*Write.*NotebookEdit'
tools_case implementer '^Read, Edit, Write, Grep, Glob, Bash$' -
tools_case implementer-risky '^Read, Edit, Write, Grep, Glob, Bash$' -
tools_case e2e-runner '^Read, Grep, Glob, Bash, Skill, mcp__' -
if grep -qE 'mcp__' <<<"$(field "$root/plugins/ogxo-route/agents/e2e-runner.md" tools | tr ',' '\n' | grep mcp__ | grep -vE 'chrome-devtools|claude-in-chrome|playwright')"; then
  fail=$((fail + 1)); echo "FAIL: e2e-runner lists a non-browser MCP server"
else
  pass=$((pass + 1))
fi

echo "agent pin tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

#!/usr/bin/env bash
# The ogxo bundle must depend on every plugin in the catalog except itself and
# the ones left out on purpose, so a new plugin can't be forgotten.
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
excluded='["ogxo", "thryx", "ogxo-format"]'

want=$(jq -r --argjson x "$excluded" '[.plugins[].name] - $x | sort[]' "$root/.claude-plugin/marketplace.json")
have=$(jq -r '.dependencies | map(if type == "object" then .name else . end) | sort[]' "$root/plugins/ogxo/.claude-plugin/plugin.json")

if [ "$want" = "$have" ]; then
  echo "bundle tests: ogxo depends on every catalog plugin except $(jq -r 'join(", ")' <<<"$excluded")"
  exit 0
fi
echo "FAIL: plugins/ogxo/.claude-plugin/plugin.json dependencies do not match the catalog."
echo "Add a new plugin to the bundle (and bump its version), or to the excluded list in tests/bundle.sh."
diff <(echo "$want") <(echo "$have") | sed 's/^</missing from bundle:/; s/^>/not in catalog:/' | grep -v '^[0-9]'
exit 1

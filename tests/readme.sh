#!/usr/bin/env bash
# The plugin table in README.md must list every catalog plugin, only catalog
# plugins, and each one at its catalog version, so a version bump can't leave
# the README behind.
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
catalog="$root/.claude-plugin/marketplace.json"
readme="$root/README.md"

want=$(jq -r '.plugins[] | "\(.name) \(.version)"' "$catalog" | sort)
# Rows look like: | `name` | description | version |
# shellcheck disable=SC2016 # the backticks are literal, not command substitution
have=$(awk '/^## Plugins$/ { table = 1; next } /^## / { table = 0 } table' "$readme" | grep -E '^\| `[^`]+` \|' | awk -F'|' '{
  name = $2; gsub(/[ `]/, "", name)
  ver = $(NF - 1); gsub(/ /, "", ver)
  print name " " ver
}' | sort)

if [ -z "$have" ]; then
  echo "FAIL: no plugin rows found in README.md; did the table format change?"
  exit 1
fi
if [ "$want" = "$have" ]; then
  echo "readme tests: README.md lists all $(wc -l <<<"$want" | tr -d ' ') catalog plugins at their catalog versions"
  exit 0
fi
echo "FAIL: the plugin table in README.md does not match .claude-plugin/marketplace.json."
echo "Update the row's Status column when you bump a plugin's version, and add a row for a new plugin."
diff <(echo "$want") <(echo "$have") | sed 's/^</catalog:/; s/^>/README: /' | grep -v '^[0-9-]'
exit 1

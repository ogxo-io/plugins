#!/usr/bin/env bash
# Rendering tests for the ogxo-statusline script: each case feeds a session
# payload on stdin and checks the plain-text output (ANSI colors stripped).
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
script="$root/plugins/ogxo-statusline/scripts/ogxo-statusline.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0

render() {
  local payload=$1
  shift
  (cd "$tmp" && bash "$script" "$@") <"$payload" 2>&1 | sed $'s/\x1b\\[[0-9;]*m//g'
}

# expect <description> <payload file> <must contain> [<must not contain>] [script options...]
expect() {
  local out
  out=$(render "$2" "${@:5}")
  if [[ "$out" != *"$3"* ]]; then
    fail=$((fail + 1))
    printf 'FAIL: %s: missing %q in:\n%s\n' "$1" "$3" "$out"
  elif [ -n "${4:-}" ] && [[ "$out" == *"$4"* ]]; then
    fail=$((fail + 1))
    printf 'FAIL: %s: unexpected %q in:\n%s\n' "$1" "$4" "$out"
  else
    pass=$((pass + 1))
  fi
}

now=$(date +%s)
jq -n --argjson t $((now + 3600)) --argjson w $((now + 400000)) '{
  model: {display_name: "Opus"},
  cost: {total_duration_ms: 4523000},
  context_window: {context_window_size: 1000000, used_percentage: 42.6,
    current_usage: {input_tokens: 8500, output_tokens: 1200,
      cache_creation_input_tokens: 5000, cache_read_input_tokens: 412000}},
  prompt_cache: {hit_ratio: 0.91},
  effort: {level: "xhigh"},
  thinking: {enabled: true},
  rate_limits: {five_hour: {used_percentage: 23.5, resets_at: $t},
    seven_day: {used_percentage: 91.2, resets_at: $w},
    spend_limit: {used_percentage: 62.8, resets_at: $w}}}' >"$tmp/full.json"

expect "model" "$tmp/full.json" "Opus"
expect "context percent and tokens" "$tmp/full.json" "43% (426k/1.0m)"
expect "session time" "$tmp/full.json" "1h15m"
expect "thinking and effort" "$tmp/full.json" "thinking effort:xhigh"
expect "cache hit ratio" "$tmp/full.json" "cache:91%"
expect "5-hour window" "$tmp/full.json" "5h ●○○○○○ 24%"
expect "7-day window" "$tmp/full.json" "7d ●●●●●○ 91%"
expect "spend limit" "$tmp/full.json" "spend ●●●○○○ 63%"

jq 'del(.rate_limits)' "$tmp/full.json" >"$tmp/norate.json"
expect "no rate_limits: single line" "$tmp/norate.json" "Opus" "5h"

jq 'del(.rate_limits.five_hour, .rate_limits.spend_limit)' "$tmp/full.json" >"$tmp/partial.json"
expect "partial rate_limits" "$tmp/partial.json" "7d ●●●●●○" "5h"

echo '{"model": {"display_name": "Sonnet"}, "context_window": {"used_percentage": null, "current_usage": null}}' >"$tmp/early.json"
expect "early session nulls" "$tmp/early.json" "Sonnet" "%"

echo '{}' >"$tmp/empty-object.json"
expect "empty object" "$tmp/empty-object.json" "Claude"

: >"$tmp/empty.txt"
expect "empty stdin" "$tmp/empty.txt" "ogxo"

expect "context glyph is not an emoji" "$tmp/full.json" "◔ 43%" "✍"

# Prompt cache: warm with >10m left says nothing extra, <=10m counts down, cold says cold.
jq --argjson e $((now + 1800)) '.prompt_cache += {warm: true, caching_observed: true, expires_at: $e}' "$tmp/full.json" >"$tmp/warm.json"
expect "cache warm, far from expiry" "$tmp/warm.json" "cache:91%" "cold"
jq --argjson e $((now + 185)) '.prompt_cache += {warm: true, caching_observed: true, expires_at: $e}' "$tmp/full.json" >"$tmp/expiring.json"
expect "cache expiring soon" "$tmp/expiring.json" "cold in 3m"
jq '.prompt_cache += {warm: false, caching_observed: true, expires_at: null}' "$tmp/full.json" >"$tmp/cold.json"
expect "cache cold" "$tmp/cold.json" "cache:91% cold"

# Cost: auto shows it only without plan usage.
jq '.cost.total_cost_usd = 1.234' "$tmp/full.json" >"$tmp/cost.json"
jq 'del(.rate_limits)' "$tmp/cost.json" >"$tmp/cost-api.json"
expect "cost hidden with plan usage (auto)" "$tmp/cost.json" "Opus" '$1.23'
expect "cost shown without plan usage (auto)" "$tmp/cost-api.json" '$1.23'
expect "--cost=always" "$tmp/cost.json" '$1.23' "" --cost=always
expect "--cost=never" "$tmp/cost-api.json" "Opus" '$1.23' --cost=never

# Options.
expect "--no-usage" "$tmp/full.json" "Opus" "5h" --no-usage
expect "--no-cache" "$tmp/full.json" "Opus" "cache:" --no-cache
jq '.workspace.git_worktree = "feat-wt"' "$tmp/full.json" >"$tmp/wt.json"
expect "worktree name" "$tmp/wt.json" "[wt:feat-wt]"
# Color modes are checked on raw output, since render() strips escape codes.
# raw_lacks <description> <pattern> <command...>
raw_lacks() {
  local desc=$1 pattern=$2
  shift 2
  if "$@" <"$tmp/full.json" | grep -q "$pattern"; then
    fail=$((fail + 1))
    echo "FAIL: $desc"
  else
    pass=$((pass + 1))
  fi
}
raw_lacks "--no-color emits no escape codes" $'\x1b' bash "$script" --no-color
raw_lacks "NO_COLOR emits no escape codes" $'\x1b' env NO_COLOR=1 bash "$script"
raw_lacks "--basic-colors emits no 24-bit codes" $'\x1b\\[38;2' bash "$script" --basic-colors
if bash "$script" <"$tmp/full.json" | grep -q $'\x1b\\[38;2'; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "FAIL: default output has no 24-bit color codes"
fi

git -C "$tmp" init -q -b feature-x
git -C "$tmp" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
touch "$tmp/untracked"
jq --arg d "$tmp" '.workspace.current_dir = $d' "$tmp/norate.json" >"$tmp/git.json"
expect "git branch, dirty, changes" "$tmp/git.json" "(feature-x*) ~"
expect "--no-git" "$tmp/git.json" "Opus" "feature-x" --no-git
git -C "$tmp" -c advice.detachedHead=false checkout -q --detach
expect "detached HEAD shows short sha" "$tmp/git.json" "($(git -C "$tmp" rev-parse --short=7 HEAD)*)"

echo "statusline tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

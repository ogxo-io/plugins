#!/usr/bin/env bash
# Rendering and config-edit tests for the Grok status line.
set -uo pipefail
unset NO_COLOR

root=$(cd "$(dirname "$0")/.." && pwd)
script="$root/plugins/ogxo-statusline/scripts/ogxo-statusline-grok.sh"
cfgpy="$root/plugins/ogxo-statusline/scripts/configure-grok.py"
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

ok() {
  if [ "$1" -eq 0 ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL: %s (exit %s)\n%s\n' "$2" "$1" "$3"
  fi
}

now=$(date +%s)
turn_ms=$(( (now - 3 * 3600 - 5) * 1000 ))
jq -n --argjson turn "$turn_ms" '{
  model: {display_name: "Grok 4.7"},
  cost: {total_duration_ms: 4523000, total_cost_usd: 0.42},
  effort: {level: "high"},
  context_window: {
    context_window_size: 1000000,
    used_percentage: 12,
    context_tokens: 40000,
    session_output_tokens: 12000,
    session_usage: {input_tokens: 90, cache_read_input_tokens: 910,
      cache_creation_input_tokens: 0, output_tokens: 99999}
  },
  workspace: {git_worktree: "feat-wt"},
  turn: {started_at_ms: $turn},
  thinking: {enabled: true},
  rate_limits: {five_hour: {used_percentage: 23}}
}' >"$tmp/full.json"

expect "model" "$tmp/full.json" "Grok 4.7"
expect "live context, not session totals" "$tmp/full.json" "12% (40k/1.0m)" "5.0m"
expect "session time" "$tmp/full.json" "1h15m"
expect "active turn from local clock" "$tmp/full.json" "turn 3h0m"
expect "effort without thinking" "$tmp/full.json" "effort:high" "thinking"
expect "session output, not session_usage.output_tokens" "$tmp/full.json" "out:12k" "100k"
expect "session cache-read share" "$tmp/full.json" "cache:91%"
expect "cost" "$tmp/full.json" '$0.42'
expect "worktree" "$tmp/full.json" "[wt:feat-wt]"
expect "no plan-usage line" "$tmp/full.json" "Grok 4.7" "5h"
expect "context glyph" "$tmp/full.json" "◔ 12%" "✍"

# A huge session input must not replace context_tokens in the fraction.
jq '.context_window.session_usage.input_tokens = 5000000 | .context_window.context_tokens = 1000 | .context_window.used_percentage = 1 | .context_window.session_usage.cache_read_input_tokens = 0' "$tmp/full.json" >"$tmp/live.json"
expect "fraction stays on context_tokens" "$tmp/live.json" "1% (1k/1.0m)" "5.0m"

jq 'del(.turn)' "$tmp/full.json" >"$tmp/noturn.json"
expect "no turn between turns" "$tmp/noturn.json" "1h15m" "turn "

jq 'del(.cost.total_cost_usd)' "$tmp/full.json" >"$tmp/nocost.json"
expect "absent cost is omitted" "$tmp/nocost.json" "Grok 4.7" '$'

echo '{"model": {"display_name": "Grok 4"}, "context_window": {"used_percentage": null, "context_tokens": null}}' >"$tmp/early.json"
expect "early session nulls" "$tmp/early.json" "Grok 4" "%"

echo '{}' >"$tmp/empty-object.json"
expect "empty object" "$tmp/empty-object.json" "Grok"

: >"$tmp/empty.txt"
expect "empty stdin" "$tmp/empty.txt" "ogxo"

mkdir -p "$tmp/bin"
for cmd in cat date awk git sed tr; do
  src=$(PATH="/bin:/usr/bin:/usr/local/bin:/opt/homebrew/bin" command -v "$cmd" || true)
  [ -n "$src" ] && ln -sf "$src" "$tmp/bin/$cmd"
done
out=$(PATH="$tmp/bin" "$(command -v bash)" "$script" <<<"{}")
if [ "$out" = "ogxo" ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: missing jq: %q\n' "$out"
fi

expect "--no-cache" "$tmp/full.json" "Grok 4.7" "cache:" --no-cache
expect "--cost=never" "$tmp/full.json" "Grok 4.7" '$0.42' --cost=never
expect "--no-color emits no escapes" "$tmp/full.json" "Grok 4.7" $'\x1b' --no-color
if NO_COLOR=1 bash "$script" <"$tmp/full.json" | grep -q $'\x1b'; then
  fail=$((fail + 1))
  echo "FAIL: NO_COLOR still emits escape codes"
else
  pass=$((pass + 1))
fi
basic=$(bash "$script" --basic-colors <"$tmp/full.json")
if printf '%s' "$basic" | grep -q $'\x1b\[38;2'; then
  fail=$((fail + 1))
  echo "FAIL: --basic-colors still emits 24-bit color codes"
elif printf '%s' "$basic" | grep -q $'\x1b\[34m'; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "FAIL: --basic-colors emitted no 16-color codes"
fi
if bash "$script" <"$tmp/full.json" | grep -q $'\x1b\[38;2'; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "FAIL: default output has no 24-bit color codes"
fi

git -C "$tmp" init -q -b feature-x
git -C "$tmp" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
touch "$tmp/untracked"
jq --arg d "$tmp" '.workspace.current_dir = $d' "$tmp/noturn.json" >"$tmp/git.json"
expect "git branch, dirty, changes" "$tmp/git.json" "(feature-x*) ~"
expect "--no-git" "$tmp/git.json" "Grok 4.7" "feature-x" --no-git
git -C "$tmp" -c advice.detachedHead=false checkout -q --detach
expect "detached HEAD shows short sha" "$tmp/git.json" "($(git -C "$tmp" rev-parse --short=7 HEAD)*)"

# ── config.toml editor ──────────────────────────────────
home="$tmp/home"
fake="$tmp/fakehome"
out=$(python3 "$cfgpy" check --home "$home")
code=$?
if [ "$code" -eq 0 ] && [[ "$out" == *"status=absent"* ]] && [ ! -e "$home/config.toml" ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: check absent creates nothing\n%s\n' "$out"
fi

mkdir -p "$home"
printf '%s\n' '# keep' '[agent]' 'model = "grok"' >"$home/config.toml"
out=$(python3 "$cfgpy" install --home "$home")
code=$?
ok "$code" "install into existing config" "$out"
python3 - "$home/config.toml" <<'PY'
import sys, tomllib
from pathlib import Path
text = Path(sys.argv[1]).read_text()
data = tomllib.loads(text)
assert text.startswith("# keep\n"), text
assert data["agent"]["model"] == "grok"
row = data["ui"]["status_line"]
assert row["type"] == "command"
assert row["command"].endswith("/ogxo-statusline.sh")
assert row["padding"] == 0
assert row["refresh_interval"] == 60
assert Path(sys.argv[1] + ".bak").read_text().startswith("# keep\n")
PY
ok "$?" "installed toml keeps other tables" ""

out=$(python3 "$cfgpy" check --home "$home")
code=$?
if [ "$code" -eq 0 ] && [[ "$out" == *"status=match"* ]]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: check match\n%s\n' "$out"
fi

# Options after the program still count as this script.
script_path=$(python3 "$cfgpy" check --home "$home" | sed -n 's/^command_expected=//p')
cat >"$home/config.toml" <<EOF
[ui.status_line]
type = "command"
command = "$script_path --no-git"
padding = 2
EOF
out=$(python3 "$cfgpy" check --home "$home")
if [[ "$out" == *"status=match"* ]] && [[ "$out" == *"command=$script_path --no-git"* ]]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: options still match\n%s\n' "$out"
fi

cat >"$home/config.toml" <<EOF
[agent]
model = "grok"

[ui.status_line]
type = "builtin"
items = ["cwd", "model"]

[mcp_servers.demo]
command = "demo"
EOF
out=$(python3 "$cfgpy" uninstall --home "$home")
code=$?
if [ "$code" -eq 1 ] && [[ "$out" == *"status=other"* ]] && grep -q 'type = "builtin"' "$home/config.toml"; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: uninstall leaves a different status line\n%s\n' "$out"
fi

out=$(python3 "$cfgpy" install --home "$home" --command "$script_path --cost=never")
code=$?
ok "$code" "replace builtin table" "$out"
python3 - "$home/config.toml" "$script_path --cost=never" <<'PY'
import sys, tomllib
from pathlib import Path
text = Path(sys.argv[1]).read_text()
data = tomllib.loads(text)
assert data["agent"]["model"] == "grok"
assert data["mcp_servers"]["demo"]["command"] == "demo"
assert data["ui"]["status_line"]["command"] == sys.argv[2]
assert "builtin" not in text
PY
ok "$?" "replace keeps surrounding tables" ""

out=$(python3 "$cfgpy" uninstall --home "$home")
code=$?
ok "$code" "uninstall matching command" "$out"
python3 - "$home/config.toml" <<'PY'
import sys, tomllib
from pathlib import Path
text = Path(sys.argv[1]).read_text()
data = tomllib.loads(text)
assert "status_line" not in data.get("ui", {})
assert data["agent"]["model"] == "grok"
assert data["mcp_servers"]["demo"]["command"] == "demo"
assert "[agent]\nmodel" in text
assert "\n\n[mcp_servers.demo]" in text
PY
ok "$?" "uninstall leaves neighbor tables" ""

printf '%s\n' '[ui.status_line]' 'type = "command"' "command = \"$script_path\"" >"$home/config.toml"
out=$(python3 "$cfgpy" uninstall --home "$home")
code=$?
if [ "$code" -eq 0 ] && [[ "$out" == *"file=deleted"* ]] && [ ! -e "$home/config.toml" ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: uninstall of an only-status-line file\n%s\n' "$out"
fi

printf '%s\n' '[ui]' 'vim_mode = true' 'status_line.type = "builtin"' >"$home/config.toml"
before=$(cat "$home/config.toml")
out=$(python3 "$cfgpy" install --home "$home")
code=$?
after=$(cat "$home/config.toml")
if [ "$code" -eq 2 ] && [[ "$out" == *"status=inline"* ]] && [ "$before" = "$after" ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: inline keys refused\n%s\n' "$out"
fi

printf '%s\n' '[ui.status_line]' 'type = "builtin"' '' '[ui.status_line]' 'type = "command"' >"$home/config.toml"
before=$(cat "$home/config.toml")
out=$(python3 "$cfgpy" install --home "$home")
code=$?
after=$(cat "$home/config.toml")
if [ "$code" -eq 2 ] && [[ "$out" == *"status=ambiguous"* ]] && [ "$before" = "$after" ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: duplicate table refused\n%s\n' "$out"
fi

rm -f "$home/config.toml" "$home/config.toml.bak"
mkdir -p "$tmp/real"
printf '%s\n' '[agent]' 'model = "linked"' >"$tmp/real/config.toml"
ln -s "$tmp/real/config.toml" "$home/config.toml"
out=$(python3 "$cfgpy" install --home "$home")
code=$?
if [ "$code" -eq 0 ] && [ -L "$home/config.toml" ] && grep -q 'ogxo-statusline.sh' "$tmp/real/config.toml" && grep -q 'model = "linked"' "$tmp/real/config.toml"; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: symlink config edits the target\n%s\n' "$out"
fi
rm "$home/config.toml"

mkdir -p "$fake/.grok"
out=$(HOME="$fake" python3 "$cfgpy" install --home "$fake/.grok")
code=$?
if [ "$code" -eq 0 ] && grep -q 'command = "~/.grok/ogxo-statusline.sh"' "$fake/.grok/config.toml"; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: default home uses tilde command\n%s\n' "$out"
fi
out=$(HOME="$fake" python3 "$cfgpy" check --home "$fake/.grok")
if [[ "$out" == *"status=match"* ]] && [[ "$out" == *"command_expected=~/.grok/ogxo-statusline.sh"* ]]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: tilde command matches\n%s\n' "$out"
fi

echo "statusline-grok tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

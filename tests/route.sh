#!/usr/bin/env bash
# Tests for the ogxo-route hooks and scripts. Each case pipes a crafted
# payload into a script with CLAUDE_PLUGIN_ROOT/CLAUDE_PLUGIN_DATA pointed at
# the plugin and a temp dir, then checks exit code, stdout, and state files.
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
plugin="$root/plugins/ogxo-route"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
data="$tmp/data"

pass=0
fail=0

# expect <description> <command...>: pass when the command succeeds.
expect() {
  local desc=$1
  shift
  if "$@" >/dev/null 2>&1; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: $desc"
  fi
}

# run_hook <script path> <payload> [VAR=value ...]: sets $out and $code.
run_hook() {
  local script=$1 payload=$2
  shift 2
  out=$(printf '%s' "$payload" | env CLAUDE_PLUGIN_ROOT="$plugin" CLAUDE_PLUGIN_DATA="$data" "$@" bash "$script" 2>"$tmp/err")
  code=$?
}

# A PATH with bash, date and coreutils but no jq, for the jq-missing cases.
nojq="$tmp/nojq"
mkdir -p "$nojq"
for b in bash date cat mkdir printf env awk sed; do
  p=$(command -v "$b") && ln -sf "$p" "$nojq/$b"
done

reset_data() { rm -rf "$data"; mkdir -p "$data"; }
lines() { [ -f "$1" ] && wc -l <"$1" | tr -d ' ' || echo 0; }

# --- dispatch-log ------------------------------------------------------------
log="$plugin/hooks/dispatch-log.sh"

reset_data
run_hook "$log" '{"session_id":"s1","tool_input":{"subagent_type":"ogxo-route:scout","prompt":"secret text"}}'
expect "dispatch-log: exit 0" [ "$code" -eq 0 ]
expect "dispatch-log: one line" [ "$(lines "$data/dispatches.jsonl")" = 1 ]
expect "dispatch-log: fields" jq -e '.subagent_type == "ogxo-route:scout" and .requested_model == null and .nested == false and .session_id == "s1" and (.ts | type == "number")' "$data/dispatches.jsonl"
expect "dispatch-log: no prompt text logged" bash -c "! grep -q 'secret text' '$data/dispatches.jsonl'"

run_hook "$log" '{"session_id":"s1","agent_id":"a1","tool_input":{"subagent_type":"Explore","model":"haiku"}}'
expect "dispatch-log: nested + model" jq -se '.[1].nested == true and .[1].requested_model == "haiku"' "$data/dispatches.jsonl"

run_hook "$log" '{"session_id":"s1","tool_input":{"prompt":"x"}}'
expect "dispatch-log: bare dispatch records empty type" jq -se '.[2].subagent_type == ""' "$data/dispatches.jsonl"

run_hook "$log" 'not json'
expect "dispatch-log: garbage stdin exits 0" [ "$code" -eq 0 ]
expect "dispatch-log: garbage stdin adds nothing" [ "$(lines "$data/dispatches.jsonl")" = 3 ]

out=$(cd "$tmp" && printf '{}' | env -u CLAUDE_PLUGIN_DATA CLAUDE_PLUGIN_ROOT="$plugin" bash "$log" 2>/dev/null)
code=$?
expect "dispatch-log: no data dir exits 0" [ "$code" -eq 0 ]
expect "dispatch-log: no data dir writes nothing in cwd" [ ! -e "$tmp/dispatches.jsonl" ]

reset_data
run_hook "$log" '{"tool_input":{"subagent_type":"Explore"}}' PATH="$nojq"
expect "dispatch-log: no jq prints notice" grep -q 'jq not found' "$tmp/err"
expect "dispatch-log: no jq writes nothing" [ ! -e "$data/dispatches.jsonl" ]

# --- generic-warn ------------------------------------------------------------
warn="$plugin/hooks/generic-warn.sh"

for t in Explore general-purpose Plan; do
  run_hook "$warn" "{\"tool_input\":{\"subagent_type\":\"$t\",\"prompt\":\"x\"}}"
  expect "generic-warn: $t without model exits 0" [ "$code" -eq 0 ]
  expect "generic-warn: $t without model warns" jq -e --arg t "$t" '.hookSpecificOutput.hookEventName == "PreToolUse" and (.hookSpecificOutput.additionalContext | contains($t)) and (.hookSpecificOutput | has("permissionDecision") | not)' <<<"$out"
done

run_hook "$warn" '{"tool_input":{"prompt":"x"}}'
expect "generic-warn: bare dispatch warns" jq -e '.hookSpecificOutput.additionalContext | contains("general-purpose")' <<<"$out"

run_hook "$warn" '{"tool_input":{"subagent_type":"Explore","model":"haiku"}}'
expect "generic-warn: model given is silent" [ -z "$out" ]
run_hook "$warn" '{"tool_input":{"subagent_type":"ogxo-route:scout"}}'
expect "generic-warn: named worker is silent" [ -z "$out" ]
run_hook "$warn" 'not json'
expect "generic-warn: garbage exits 0 silently" test "$code" -eq 0 -a -z "$out"

run_hook "$warn" '{"tool_input":{"subagent_type":"Explore"}}' PATH="$nojq"
expect "generic-warn: no jq prints notice" grep -q 'jq not found' "$tmp/err"

# --- anchor ------------------------------------------------------------------
anchor="$plugin/hooks/anchor.sh"
now=$(date +%s)

reset_data
out=$(printf '{}' | env -u CLAUDECODE CLAUDE_PLUGIN_ROOT="$plugin" CLAUDE_PLUGIN_DATA="$data" bash "$anchor" 2>/dev/null)
expect "anchor: silent outside Claude Code" [ -z "$out" ]

run_hook "$anchor" '{}' CLAUDECODE=1
expect "anchor: exit 0" [ "$code" -eq 0 ]
expect "anchor: prints the summary" grep -q 'ogxo-route is active' <<<"$out"
expect "anchor: no markers without external.json" bash -c "! grep -q ' is marked off' <<<\"\$1\"" _ "$out"

jq -n --argjson f $((now + 3600)) --argjson p $((now - 10)) '{codex: {off_until: $f}, grok: {off_until: $p}}' >"$data/external.json"
run_hook "$anchor" '{}' CLAUDECODE=1
expect "anchor: unexpired marker shown" grep -q 'codex is marked off' <<<"$out"
expect "anchor: expired marker hidden" bash -c "! grep -q 'grok is marked off' <<<\"\$1\"" _ "$out"

printf 'not json' >"$data/external.json"
run_hook "$anchor" '{}' CLAUDECODE=1
expect "anchor: corrupt external.json still prints summary" grep -q 'ogxo-route is active' <<<"$out"
expect "anchor: corrupt external.json exits 0" [ "$code" -eq 0 ]

run_hook "$anchor" '{}' CLAUDECODE=1 PATH="$nojq"
expect "anchor: no jq still prints summary" grep -q 'ogxo-route is active' <<<"$out"

# --- external.sh -------------------------------------------------------------
ext="$plugin/scripts/external.sh"
runx() { out=$(env CLAUDE_PLUGIN_DATA="$data" bash "$@" 2>"$tmp/err"); code=$?; }

reset_data
runx "$ext"
expect "external: status when empty" grep -q 'codex: on' <<<"$out"
runx "$ext" off codex 2
now=$(date +%s)
expect "external: off exit 0" [ "$code" -eq 0 ]
expect "external: off writes until ~now+2h" jq -e --argjson n "$now" '(.codex.off_until - ($n + 7200)) | fabs < 60' "$data/external.json"
runx "$ext"
expect "external: status shows off" grep -q 'codex: off until' <<<"$out"
runx "$ext" on codex
expect "external: on removes marker" jq -e 'has("codex") | not' "$data/external.json"
runx "$ext" off foo
expect "external: unknown agent exit 2" [ "$code" -eq 2 ]
runx "$ext" off codex abc
expect "external: bad hours exit 2" [ "$code" -eq 2 ]
printf 'not json' >"$data/external.json"
runx "$ext" off grok
expect "external: recovers from corrupt file" jq -e '.grok.off_until | type == "number"' "$data/external.json"

# --- stats.sh ----------------------------------------------------------------
stats="$plugin/scripts/stats.sh"
reset_data
runx "$stats"
expect "stats: empty log" grep -q 'No dispatches recorded yet' <<<"$out"

now=$(date +%s)
{
  jq -nc --argjson t "$now" '{ts:$t, session_id:"s", subagent_type:"ogxo-route:scout", requested_model:null, nested:false}'
  jq -nc --argjson t "$now" '{ts:$t, session_id:"s", subagent_type:"Explore", requested_model:null, nested:false}'
  jq -nc --argjson t "$now" '{ts:$t, session_id:"s", subagent_type:"", requested_model:null, nested:true}'
  jq -nc --argjson t "$now" '{ts:$t, session_id:"s", subagent_type:"Explore", requested_model:"haiku", nested:false}'
  printf '{"ts":%s,"subagent_type":"broken\n' "$now"
  jq -nc --argjson t $((now - 40 * 86400)) '{ts:$t, session_id:"s", subagent_type:"old", requested_model:null, nested:false}'
} >"$data/dispatches.jsonl"
runx "$stats" 7
expect "stats: exit 0" [ "$code" -eq 0 ]
expect "stats: total counts valid recent lines" grep -q 'Dispatches in the last 7 days: 4 (1 from inside subagents)' <<<"$out"
expect "stats: generic with no model" grep -q 'Generic dispatches with no model: 2' <<<"$out"
expect "stats: bare dispatch labelled" grep -q '(none)' <<<"$out"
expect "stats: old and malformed lines pruned" [ "$(lines "$data/dispatches.jsonl")" = 4 ]
runx "$stats" x
expect "stats: bad days exit 2" [ "$code" -eq 2 ]

# --- skill and anchor name only agents that exist ----------------------------
skill="$plugin/skills/routing/SKILL.md"
expect "skill: exists" [ -f "$skill" ]
for f in "$skill" "$plugin/hooks/anchor.md"; do
  for a in $(grep -oE 'ogxo-route:[a-z0-9-]+' "$f" 2>/dev/null | sort -u); do
    n=${a#ogxo-route:}
    [ "$n" = routing ] || [ "$n" = external ] || [ "$n" = stats ] && continue
    expect "$(basename "$f") names existing agent $a" [ -f "$plugin/agents/$n.md" ]
  done
done

# --- final-review fixes -------------------------------------------------------
risky="$plugin/scripts/risky-paths.sh"
paths='services/api/handler.go
src/pricing.ts
docs/decisions/adr-1.md
package-lock.json
pkg/blockchain/block.go
src/oracle/feed.ts
docs/release-notes.md
src/auth/login.ts
src/authentication/jwt.go
db/migrations/001_init.sql
query.sql
.github/workflows/test.yml
src/ci/run.sh
Dockerfile
deploy/prod.yaml
src/payments/charge.ts
internal/cache/store.go'
got=$(printf '%s\n' "$paths" | bash "$risky" 2>/dev/null)
want='src/auth/login.ts
src/authentication/jwt.go
db/migrations/001_init.sql
query.sql
.github/workflows/test.yml
src/ci/run.sh
Dockerfile
deploy/prod.yaml
src/payments/charge.ts
internal/cache/store.go'
expect "risky-paths: matches path segments, not substrings" [ "$got" = "$want" ]
got=$(printf 'contracts/Token.sol\nsrc/app.ts\n' | bash "$risky" 'contracts/' 2>/dev/null)
expect "risky-paths: extra patterns from arguments" [ "$got" = "contracts/Token.sol" ]
expect "verifier: runs risky-paths.sh" grep -q 'scripts/risky-paths.sh' "$plugin/agents/verifier.md"
expect "hooks: SessionStart covers fork" jq -e '.hooks.SessionStart[0].matcher | split("|") | index("fork") != null' "$plugin/hooks/hooks.json"
expect "skill: user-only reviews cite the mechanism" grep -q 'disable-model-invocation' "$plugin/skills/routing/SKILL.md"
expect "README: e2e-runner tools row is accurate" grep -qE '^\| `e2e-runner` .*Read, Grep, Glob, Bash, Skill' "$plugin/README.md"

# --- state-file robustness -----------------------------------------------------
perms() { ls -l "$1" | cut -c1-10; }
reset_data
now=$(date +%s)
jq -nc --argjson t "$now" '{ts:$t, session_id:"s", subagent_type:"Explore", requested_model:null, nested:false}' >"$data/dispatches.jsonl"
before=$(ls -i "$data/dispatches.jsonl" | awk '{print $1}')
runx "$stats"
after=$(ls -i "$data/dispatches.jsonl" | awk '{print $1}')
expect "stats: no rewrite when nothing to prune" [ "$before" = "$after" ]

: >"$tmp/umask-ref"
jq -nc --argjson t $((now - 40 * 86400)) '{ts:$t, subagent_type:"old", requested_model:null, nested:false}' >>"$data/dispatches.jsonl"
printf '42\n"x"\n' >>"$data/dispatches.jsonl"
runx "$stats"
expect "stats: non-object lines are silent" [ ! -s "$tmp/err" ]
expect "stats: prune keeps umask permissions" [ "$(perms "$data/dispatches.jsonl")" = "$(perms "$tmp/umask-ref")" ]
expect "stats: no temp files left" [ "$(ls "$data" | grep -vcE '^dispatches\.jsonl$')" = 0 ]

reset_data
printf '{"codex":{"off_until":"x"}}' >"$data/external.json"
runx "$ext"
expect "external: non-numeric off_until reads as on" grep -q 'codex: on' <<<"$out"
expect "external: non-numeric off_until is silent" [ ! -s "$tmp/err" ]
runx "$ext" off grok 1
expect "external: write keeps umask permissions" [ "$(perms "$data/external.json")" = "$(perms "$tmp/umask-ref")" ]
expect "external: no temp files left" [ "$(ls "$data" | grep -vcE '^external\.json$')" = 0 ]

# --- quota-watch -------------------------------------------------------------
qw="$plugin/hooks/quota-watch.sh"
grok402='[grok-cc] Grok exited with status 1.
Internal error: {
  "message": "API error (status 402 Payment Required): Grok Build usage balance exhausted",
  "http_status": 402
}'
marked() { jq -e '(.grok.off_until | type) == "number"' "$data/external.json" >/dev/null 2>&1; }

reset_data
run_hook "$qw" "$(jq -nc --arg r "$grok402" '{tool_name:"Agent", tool_input:{subagent_type:"grok-build:grok-delegate"}, tool_response:{content:[{type:"text", text:$r}]}}')"
expect "quota-watch: grok agent 402 exit 0" [ "$code" -eq 0 ]
expect "quota-watch: grok agent 402 marks grok off" marked
now=$(date +%s)
expect "quota-watch: marker is ~24h" jq -e --argjson n "$now" '(.grok.off_until - ($n + 86400)) | fabs < 60' "$data/external.json"
expect "quota-watch: tells Claude" jq -e '.hookSpecificOutput.hookEventName == "PostToolUse" and (.hookSpecificOutput.additionalContext | contains("marked off")) and (.hookSpecificOutput.additionalContext | contains("do not substitute")) and (has("decision") | not)' <<<"$out"

reset_data
run_hook "$qw" "$(jq -nc --arg r "$grok402" '{tool_name:"Bash", tool_input:{command:"node \"/x/grok-build/0.2.1/scripts/grok-bridge.mjs\" review --wait"}, tool_response:{stdout:"", stderr:$r}}')"
expect "quota-watch: grok bridge via Bash marks grok off" marked

reset_data
run_hook "$qw" "$(jq -nc '{tool_name:"Agent", tool_input:{subagent_type:"grok-build:grok-delegate"}, tool_response:"API error (status 429 Too Many Requests): rate limit exceeded"}')"
expect "quota-watch: 429 does not mark" bash -c '! [ -e "$1" ]' _ "$data/external.json"
expect "quota-watch: 429 is silent" [ -z "$out" ]

run_hook "$qw" "$(jq -nc --arg r "$grok402" '{tool_name:"Agent", tool_input:{subagent_type:"ogxo-route:scout"}, tool_response:$r}')"
expect "quota-watch: other agent quoting 402 does not mark" bash -c '! [ -e "$1" ]' _ "$data/external.json"
run_hook "$qw" "$(jq -nc --arg r "$grok402" '{tool_name:"Agent", tool_input:{subagent_type:"codex:codex-rescue"}, tool_response:$r}')"
expect "quota-watch: codex run does not mark grok" bash -c '! [ -e "$1" ]' _ "$data/external.json"
run_hook "$qw" "$(jq -nc --arg r "$grok402" '{tool_name:"Bash", tool_input:{command:"cat notes.txt"}, tool_response:{stdout:$r}}')"
expect "quota-watch: unrelated Bash does not mark" bash -c '! [ -e "$1" ]' _ "$data/external.json"
run_hook "$qw" 'not json'
expect "quota-watch: garbage exits 0" [ "$code" -eq 0 ]

out=$(cd "$tmp" && jq -nc --arg r "$grok402" '{tool_input:{subagent_type:"grok-build:grok-delegate"}, tool_response:$r}' | env -u CLAUDE_PLUGIN_DATA CLAUDE_PLUGIN_ROOT="$plugin" bash "$qw" 2>/dev/null)
code=$?
expect "quota-watch: no data dir exits 0" [ "$code" -eq 0 ]
expect "quota-watch: no data dir writes nothing in cwd" [ ! -e "$tmp/external.json" ]

reset_data
run_hook "$qw" "$(jq -nc --arg r "$grok402" '{tool_input:{subagent_type:"grok-build:grok-delegate"}, tool_response:$r}')" PATH="$nojq"
expect "quota-watch: no jq prints notice" grep -q 'jq not found' "$tmp/err"
expect "quota-watch: no jq writes nothing" bash -c '! [ -e "$1" ]' _ "$data/external.json"
expect "hooks: quota-watch registered on Agent|Task|Bash" jq -e '[.hooks.PostToolUse[] | select(.matcher == "Agent|Task|Bash") | .hooks[].command | contains("quota-watch.sh")] | any' "$plugin/hooks/hooks.json"

# --- data dir shown, agent_type logged ----------------------------------------
reset_data
run_hook "$log" '{"session_id":"s1","agent_id":"a1","agent_type":"Explore","tool_input":{"subagent_type":"ogxo-route:scout"}}'
expect "dispatch-log: records the parent agent_type when nested" jq -e '.agent_type == "Explore" and .nested == true' "$data/dispatches.jsonl"
run_hook "$log" '{"session_id":"s1","tool_input":{"subagent_type":"ogxo-route:scout"}}'
expect "dispatch-log: agent_type null at top level" jq -se '.[1].agent_type == null' "$data/dispatches.jsonl"
runx "$stats"
expect "stats: prints the log path" grep -qF "Log: $data/dispatches.jsonl" <<<"$out"
reset_data
runx "$stats"
expect "stats: empty log prints the log path" grep -qF "$data/dispatches.jsonl" <<<"$out"
runx "$ext"
expect "external: status prints the state file" grep -qF "State: $data/external.json" <<<"$out"

# --- parallel batches ---------------------------------------------------------
expect "skill: batch table before parallel work" grep -q 'Batch table' "$skill"
expect "skill: at most two concurrent writers" grep -qi 'at most two' "$skill"
expect "skill: forbids git state changes in worker briefs" grep -q 'git add, commit, stash, checkout, reset, or restore' "$skill"
expect "skill: isolated worktrees start from HEAD" grep -qF 'git worktree add .claude/worktrees/<task> -b task/<task> HEAD' "$skill"
expect "skill: worktrees do not isolate databases or ports" grep -qi 'test databases, ports' "$skill"
expect "skill: grok via bridge with --write" grep -qF 'grok-bridge.mjs run --background --write' "$skill"
expect "anchor: mentions parallel batches" grep -qi 'parallel' "$plugin/hooks/anchor.md"
expect "README: parallel work section" grep -q '^## Parallel work' "$plugin/README.md"

# --- self-review 2026-09: build cache, cleanup, blocked workers, review loops ---
expect "skill: no per-task build output example" bash -c '! grep -qF "CARGO_TARGET_DIR=target/<task>" "$1"' _ "$skill"
expect "skill: build caches shared by default" grep -q 'Build outputs and dependency caches are shared by default' "$skill"
expect "skill: free-disk check before a worktree" grep -qF 'df -Pk .' "$skill"
expect "skill: cleanup removes what was created outside the worktree" grep -q 'nothing created outside it' "$skill"
expect "skill: watchers act on half-finished work" grep -q 'half-finished work' "$skill"
expect "skill: append in a block headed by the task id" grep -q 'block headed by the task id' "$skill"
expect "skill: fix-round drift check" grep -qF 'status --porcelain' "$skill"
expect "skill: external writes one call per message" grep -q 'one call per message' "$skill"
expect "skill: denied actions are skipped and reported" grep -q 'If an action is denied, skip it' "$skill"
expect "skill: no compound cd in briefs" grep -qF 'not `cd <dir> && ...`' "$skill"
expect "skill: review stopping rule" grep -q 'After two fix rounds' "$skill"
for a in implementer implementer-risky; do
  expect "$a: denied actions are skipped" grep -q 'If an action is denied, skip it' "$plugin/agents/$a.md"
  expect "$a: failing test first" grep -q 'it must fail' "$plugin/agents/$a.md"
  expect "$a: no browser runs" grep -q 'Do not launch browsers' "$plugin/agents/$a.md"
done
expect "anchor: shared build cache" grep -q 'shared build cache' "$plugin/hooks/anchor.md"

echo "route tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

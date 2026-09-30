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
    [ "$n" = routing ] || [ "$n" = external ] || [ "$n" = stats ] || [ "$n" = dashboard ] && continue
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

# --- advisor ------------------------------------------------------------------
expect "skill: advisor step" grep -q '^## Step 6: advisor' "$skill"
expect "skill: advisor before choosing an approach on risky work" grep -q 'before choosing an approach on risky' "$skill"
expect "skill: advisor before declaring risky work or a branch done" grep -q 'before declaring a risky task or a branch done' "$skill"
expect "skill: advisor when stuck after an escalation" grep -q 'when stuck after an escalation' "$skill"
expect "skill: no advisor for standard work" grep -q 'Do not consult it for standard work' "$skill"
expect "anchor: advisor rule" grep -q 'If the advisor tool exists' "$plugin/hooks/anchor.md"

# --- permission log, prompt alerts ---------------------------------------------
plog="$plugin/hooks/permission-log.sh"
palert="$plugin/hooks/prompt-alert.sh"
alerts="$plugin/scripts/alerts.sh"
stats="$plugin/scripts/stats.sh"

reset_data
run_hook "$plog" '{"session_id":"s1","hook_event_name":"PermissionRequest","tool_name":"Bash","permission_mode":"auto","agent_id":"a1","agent_type":"ogxo-route:implementer","tool_input":{"command":"rm secret-file"}}'
expect "permission-log: exit 0" [ "$code" -eq 0 ]
expect "permission-log: no output, so no decision" [ -z "$out" ]
expect "permission-log: fields" jq -e '.event == "PermissionRequest" and .tool == "Bash" and .mode == "auto" and .nested == true and .agent_type == "ogxo-route:implementer"' "$data/permissions.jsonl"
expect "permission-log: no command text logged" bash -c "! grep -q 'secret-file' '$data/permissions.jsonl'"
run_hook "$plog" '{"session_id":"s1","hook_event_name":"Notification","notification_type":"permission_prompt","message":"Claude needs permission to run rm secret-file"}'
expect "permission-log: notification logged" jq -se '.[1].event == "Notification" and .[1].notification_type == "permission_prompt" and .[1].nested == false' "$data/permissions.jsonl"
expect "permission-log: no message text logged" bash -c "! grep -q 'secret-file' '$data/permissions.jsonl'"
run_hook "$plog" 'not json'
expect "permission-log: garbage exits 0" [ "$code" -eq 0 ]
run_hook "$plog" '{}' PATH="$nojq"
expect "permission-log: no jq prints notice" grep -q 'jq not found' "$tmp/err"

runx "$stats"
expect "stats: permission section" grep -q 'Permission requests in the last 7 days: 1 (1 from inside subagents)' <<<"$out"
expect "stats: notification count" grep -q 'Prompt notifications: 1' <<<"$out"
expect "stats: permission log path" grep -qF "Permission log: $data/permissions.jsonl" <<<"$out"

# Stand-ins for the notifiers, recording their arguments.
shim="$tmp/shim"
mkdir -p "$shim"
for b in osascript notify-send curl terminal-notifier; do
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s $*" >>"%s/calls"\n' "$b" "$tmp" >"$shim/$b"
  chmod +x "$shim/$b"
done
# PATH for prompt-alert runs: the stand-ins plus jq and bash only, so a real
# terminal-notifier, osascript, or notify-send on the machine never fires.
sys="$tmp/sys"
mkdir -p "$sys"
for b in bash jq cat git basename dirname; do
  p=$(command -v "$b") && ln -sf "$p" "$sys/$b"
done
note='{"hook_event_name":"Notification","notification_type":"permission_prompt","message":"Claude needs permission to run rm secret-file"}'

reset_data
rm -f "$tmp/calls"
run_hook "$palert" "$note" PATH="$shim:$sys"
expect "prompt-alert: off by default, exit 0" [ "$code" -eq 0 ]
expect "prompt-alert: off by default, no notifier" [ ! -e "$tmp/calls" ]

runx "$alerts" on
expect "alerts: on" grep -q 'Alerts on' <<<"$out"
expect "alerts: state enabled" jq -e '.enabled == true and (has("push_url") | not)' "$data/alerts.json"
mv "$shim/terminal-notifier" "$tmp/tn-aside"
run_hook "$palert" "$note" PATH="$shim:$sys"
expect "prompt-alert: desktop notification sent" grep -q '^osascript .*secret-file' "$tmp/calls"
mv "$tmp/tn-aside" "$shim/terminal-notifier"
rm -f "$tmp/calls"
run_hook "$palert" "$note" PATH="$shim:$sys" __CFBundleIdentifier=com.example.Terminal
expect "prompt-alert: terminal-notifier preferred" grep -q '^terminal-notifier .*secret-file' "$tmp/calls"
expect "prompt-alert: click activates the host app" grep -q -- '-activate com.example.Terminal' "$tmp/calls"
expect "prompt-alert: no osascript when terminal-notifier exists" bash -c "! grep -q '^osascript' '$tmp/calls'"
cp "$shim/terminal-notifier" "$tmp/tn-ok"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "terminal-notifier $*" >>"%s/calls"\nexit 3\n' "$tmp" >"$shim/terminal-notifier"
rm -f "$tmp/calls"
run_hook "$palert" "$note" PATH="$shim:$sys"
expect "prompt-alert: falls back to osascript when terminal-notifier fails" grep -q '^osascript .*secret-file' "$tmp/calls"
mv "$tmp/tn-ok" "$shim/terminal-notifier"
expect "prompt-alert: no push without a URL" bash -c "! grep -q '^curl' '$tmp/calls'"

# Where and who: project, worktree, and the asking subagent.
rm -f "$tmp/calls"
run_hook "$palert" "$note" PATH="$shim:$sys"
expect "prompt-alert: no cwd keeps the plain title" grep -q -- '-title Claude Code -subtitle main session ' "$tmp/calls"
if command -v git >/dev/null 2>&1; then
  ar="$tmp/alertrepo"
  git init -q "$ar" && git -C "$ar" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q --allow-empty -m init
  git -C "$ar" worktree add -q "$ar/.claude/worktrees/wt-a" -b wt-a 2>/dev/null
  rm -f "$tmp/calls"
  run_hook "$palert" "{\"cwd\":\"$ar\",\"notification_type\":\"permission_prompt\",\"message\":\"m\"}" PATH="$shim:$sys"
  expect "prompt-alert: title names the project" grep -q -- '-title Claude Code · alertrepo -subtitle main session ' "$tmp/calls"
  rm -f "$tmp/calls"
  run_hook "$palert" "{\"cwd\":\"$ar/.claude/worktrees/wt-a\",\"agent_type\":\"ogxo-route:implementer-risky\",\"notification_type\":\"permission_prompt\",\"message\":\"m\"}" PATH="$shim:$sys"
  expect "prompt-alert: worktree names the main repo" grep -q -- '-title Claude Code · alertrepo ' "$tmp/calls"
  expect "prompt-alert: subtitle has worktree and subagent" grep -q -- '-subtitle worktree wt-a · ogxo-route:implementer-risky ' "$tmp/calls"
fi
rm -f "$tmp/calls"
run_hook "$palert" "{\"cwd\":\"$tmp\",\"message\":\"m\"}" PATH="$shim:$sys"
expect "prompt-alert: outside a repo names the folder" grep -q -- "-title Claude Code · $(basename "$tmp") " "$tmp/calls"

rm -f "$tmp/calls"
runx "$alerts" on https://ntfy.example/topic
expect "alerts: push URL stored" jq -e '.push_url == "https://ntfy.example/topic"' "$data/alerts.json"
run_hook "$palert" "$note" PATH="$shim:$sys"
expect "prompt-alert: push posted" grep -q '^curl .*https://ntfy.example/topic' "$tmp/calls"
expect "prompt-alert: push carries no prompt text" bash -c "! grep '^curl' '$tmp/calls' | grep -q 'secret-file'"

runx "$alerts" on http://insecure.example
expect "alerts: non-https push rejected" [ "$code" -eq 2 ]
runx "$alerts" off
expect "alerts: off" jq -e '.enabled == false' "$data/alerts.json"
rm -f "$tmp/calls"
run_hook "$palert" "$note" PATH="$shim:$sys"
expect "prompt-alert: off again, no notifier" [ ! -e "$tmp/calls" ]
runx "$alerts"
expect "alerts: status prints state file" grep -qF "State: $data/alerts.json" <<<"$out"
runx "$alerts" bogus
expect "alerts: bad action exits 2" [ "$code" -eq 2 ]

expect "hooks: permission-log on PermissionRequest" jq -e '[.hooks.PermissionRequest[].hooks[].command | contains("permission-log.sh")] | any' "$plugin/hooks/hooks.json"
expect "hooks: alert on permission prompts" jq -e '[.hooks.Notification[] | select(.matcher == "permission_prompt|agent_needs_input") | .hooks[].command | contains("prompt-alert.sh")] | any' "$plugin/hooks/hooks.json"
expect "hooks: no PermissionRequest decision output anywhere" bash -c "! grep -rq 'behavior' '$plugin/hooks'"

# --- advisor count -------------------------------------------------------------
acount="$plugin/hooks/advisor-count.sh"
tr_file="$tmp/transcript.jsonl"
cat >"$tr_file" <<'JSONL'
{"type":"user","message":{"role":"user","content":"ask the advisor about secret-file"}}
{"type":"assistant","message":{"content":[{"type":"text","text":"secret-file"},{"type":"server_tool_use","id":"srv1","name":"advisor","input":{}}]}}
{"type":"assistant","message":{"content":[{"type":"server_tool_use","id":"srv1","name":"advisor","input":{}}]}}
{"type":"assistant","message":{"content":[{"type":"server_tool_use","id":"srv2","name":"advisor","input":{}},{"type":"server_tool_use","id":"srv9","name":"web_search","input":{}}]}}
not json
{"type":"assistant","message":{"content":"plain text"}}
{"type":"assistant","message":{"content":[{"type":"server_tool_use","id":"srv3","name":"advisor","input":{}}]}}
JSONL

reset_data
run_hook "$acount" "{\"session_id\":\"s1\",\"hook_event_name\":\"SessionEnd\",\"transcript_path\":\"$tr_file\"}"
expect "advisor-count: exit 0" [ "$code" -eq 0 ]
expect "advisor-count: prints nothing" [ -z "$out" ]
expect "advisor-count: unique advisor ids counted" jq -e '.session_id == "s1" and .advisor_calls == 3 and .assistant_entries == 5' "$data/advisor.jsonl"
expect "advisor-count: no text or paths logged" bash -c "! grep -qE 'secret-file|transcript' '$data/advisor.jsonl'"
run_hook "$acount" '{"session_id":"s1","hook_event_name":"SessionEnd"}'
expect "advisor-count: no transcript_path exits 0" [ "$code" -eq 0 ]
run_hook "$acount" "{\"session_id\":\"s1\",\"transcript_path\":\"$tmp/missing.jsonl\"}"
expect "advisor-count: missing transcript exits 0" [ "$code" -eq 0 ]
run_hook "$acount" 'not json'
expect "advisor-count: garbage exits 0" [ "$code" -eq 0 ]
expect "advisor-count: nothing logged for bad input" [ "$(lines "$data/advisor.jsonl")" = 1 ]
run_hook "$acount" '{}' PATH="$nojq"
expect "advisor-count: no jq prints notice" grep -q 'jq not found' "$tmp/err"
expect "hooks: advisor count on SessionEnd" jq -e '[.hooks.SessionEnd[].hooks[].command | contains("advisor-count.sh")] | any' "$plugin/hooks/hooks.json"
expect "hooks: advisor count on PreCompact" jq -e '[.hooks.PreCompact[].hooks[].command | contains("advisor-count.sh")] | any' "$plugin/hooks/hooks.json"
expect "hooks: advisor count has a timeout above the SessionEnd default" jq -e '[.hooks.SessionEnd[].hooks[] | select(.command | contains("advisor-count.sh")) | .timeout >= 10] | all and length == 1' "$plugin/hooks/hooks.json"

# stats: latest line per session, risky sessions without a call, unrecognised transcripts.
reset_data
now_ts=$(date +%s)
{
  printf '{"ts":%s,"session_id":"s1","advisor_calls":1,"assistant_entries":10}\n' "$now_ts"
  printf '{"ts":%s,"session_id":"s1","advisor_calls":4,"assistant_entries":50}\n' "$now_ts"
  printf '{"ts":%s,"session_id":"s2","advisor_calls":0,"assistant_entries":30}\n' "$now_ts"
  printf '{"ts":%s,"session_id":"s3","advisor_calls":0,"assistant_entries":0}\n' "$now_ts"
} >"$data/advisor.jsonl"
{
  printf '{"ts":%s,"session_id":"s1","subagent_type":"ogxo-route:implementer-risky","requested_model":null,"nested":false,"agent_type":null}\n' "$now_ts"
  printf '{"ts":%s,"session_id":"s2","subagent_type":"ogxo-route:implementer-risky","requested_model":null,"nested":false,"agent_type":null}\n' "$now_ts"
  printf '{"ts":%s,"session_id":"s4","subagent_type":"ogxo-route:implementer-risky","requested_model":null,"nested":false,"agent_type":null}\n' "$now_ts"
} >"$data/dispatches.jsonl"
runx "$stats"
expect "stats: advisor total uses the latest line per session" grep -q 'Advisor calls in the last 7 days: 4 across 2 ended sessions (1 with at least one)' <<<"$out"
expect "stats: risky sessions with no advisor call" grep -q 'Sessions that dispatched implementer-risky with no recorded advisor call: 1 of 2' <<<"$out"
expect "stats: unrecognised transcripts flagged" grep -q 'Transcripts with no assistant entries recognised: 1' <<<"$out"
expect "stats: advisor log path" grep -qF "Advisor log: $data/advisor.jsonl" <<<"$out"
rm -f "$data/dispatches.jsonl"
runx "$stats"
expect "stats: advisor section without dispatch log" grep -q 'Advisor calls in the last 7 days: 4' <<<"$out"
expect "stats: no risky sessions without dispatch log" grep -q 'no recorded advisor call: 0 of 0' <<<"$out"

# --- dashboard ---
dash="$plugin/hooks/dash-event.sh"
dctl="$plugin/scripts/dash.sh"
# events <sid>: the board's events.js as one JSON array.
events() { sed -e 's/^E(//' -e 's/);$//' "$data/dash/$1/events.js" 2>/dev/null | jq -s -c .; }
# last_ev <sid> <jq filter>: pass when the filter holds for the last event.
last_ev() { events "$1" | jq -e ".[-1] | $2" >/dev/null; }
board_on() { mkdir -p "$data/dash/$1"; : >"$data/dash/$1/on"; }
# hk <payload>: run the hook; count any run that exits non-zero or prints.
noisy=0
hk() {
  run_hook "$dash" "$1"
  [ "$code" -eq 0 ] && [ -z "$out" ] || noisy=$((noisy + 1))
}

reset_data
run_hook "$dash" '{"session_id":"s1","hook_event_name":"UserPromptSubmit","prompt":"hi"}'
expect "dash-event: no flag exits 0" [ "$code" -eq 0 ]
expect "dash-event: no flag prints nothing" [ -z "$out" ]
expect "dash-event: no flag writes nothing" [ ! -e "$data/dash" ]
run_hook "$dash" '{"session_id":"s1","hook_event_name":"UserPromptSubmit","prompt":"hi"}' PATH="$nojq"
expect "dash-event: no flag, no jq exits 0 silently" test "$code" -eq 0 -a -z "$out" -a ! -s "$tmp/err"
out=$(cd "$tmp" && printf '{"session_id":"s1","hook_event_name":"Stop"}' | env -u CLAUDE_PLUGIN_DATA CLAUDE_PLUGIN_ROOT="$plugin" bash "$dash" 2>/dev/null)
code=$?
expect "dash-event: no data dir exits 0 silently" test "$code" -eq 0 -a -z "$out"
expect "dash-event: no data dir writes nothing in cwd" [ ! -e "$tmp/dash" ]

board_on other
run_hook "$dash" '{"session_id":"s1","hook_event_name":"Stop"}'
expect "dash-event: other session's flag only, exit 0" [ "$code" -eq 0 ]
expect "dash-event: other session's flag only, nothing for this one" [ ! -e "$data/dash/s1" ]
expect "dash-event: other session's board untouched" [ ! -e "$data/dash/other/events.js" ]

board_on s1
run_hook "$dash" '{"session_id":"s1","hook_event_name":"Stop"}' PATH="$nojq"
expect "dash-event: flag on, no jq exits 0 silently" test "$code" -eq 0 -a -z "$out" -a ! -s "$tmp/err"
expect "dash-event: flag on, no jq writes nothing" [ ! -e "$data/dash/s1/events.js" ]

hk '{"session_id":"s1","hook_event_name":"UserPromptSubmit","prompt":"SECRET-PROMPT-1"}'
expect "dash-event: prompt event" last_ev s1 '.e == "prompt" and (.t | type == "number") and (keys == ["e", "t"])'
hk '{"session_id":"s1","hook_event_name":"Stop"}'
expect "dash-event: stop event" last_ev s1 '.e == "stop"'
hk '{"session_id":"s1","hook_event_name":"SubagentStart","agent_id":"ag1","agent_type":"ogxo-route:scout"}'
expect "dash-event: sstart event" last_ev s1 '.e == "sstart" and .id == "ag1" and .ty == "ogxo-route:scout"'
n_before=$(lines "$data/dash/s1/events.js")
hk '{"session_id":"s1","hook_event_name":"SubagentStart","agent_type":"x"}'
hk '{"session_id":"s1","hook_event_name":"SubagentStop","agent_type":"x","last_assistant_message":"VERDICT: PASS"}'
hk '{"session_id":"s1","hook_event_name":"PreCompact","trigger":"auto"}'
hk 'not json'
expect "dash-event: sstart/sstop without agent_id, unknown events and garbage write nothing" [ "$(lines "$data/dash/s1/events.js")" = "$n_before" ]

long=$(printf 'd%.0s' $(seq 1 200))
hk "$(jq -nc --arg d "$long" '{session_id:"s1", hook_event_name:"PreToolUse", tool_name:"Agent", tool_use_id:"tu1", tool_input:{subagent_type:"ogxo-route:implementer", description:$d, prompt:"SECRET-AGENT-PROMPT", model:"haiku", run_in_background:true}}')"
expect "dash-event: dispatch event" last_ev s1 '.e == "dispatch" and .a == null and .u == "tu1" and .ty == "ogxo-route:implementer" and (.d | length) == 120 and .m == "haiku" and .bg == true and (has("prompt") | not)'
hk '{"session_id":"s1","hook_event_name":"PreToolUse","tool_name":"Task","tool_use_id":"tu2","agent_id":"ag1","tool_input":{"description":"bare","prompt":"SECRET-AGENT-PROMPT"}}'
expect "dash-event: bare Task dispatch defaults" last_ev s1 '.e == "dispatch" and .a == "ag1" and .ty == "general-purpose" and .m == null and .bg == false and .d == "bare"'

# tool_sum <tool_name> <tool_input JSON> [cwd]: the summary s the hook records.
tool_sum() {
  hk "$(jq -nc --arg n "$1" --argjson i "$2" --arg c "${3:-/r}" '{session_id:"s1", hook_event_name:"PreToolUse", tool_name:$n, tool_use_id:"tx", cwd:$c, tool_input:$i}')"
  events s1 | jq -r '.[-1].s'
}
hk '{"session_id":"s1","hook_event_name":"PreToolUse","tool_name":"Read","tool_use_id":"tr1","agent_id":"ag1","agent_type":"Explore","cwd":"/r","tool_input":{"file_path":"/r/src/x.go"}}'
expect "dash-event: tool event fields" last_ev s1 '.e == "tool" and .a == "ag1" and .at == "Explore" and .u == "tr1" and .n == "Read" and .s == "src/x.go" and (has("x") | not)'
expect "dash-event: Write keeps paths outside cwd, drops content" [ "$(tool_sum Write '{"file_path":"/elsewhere/y.go","content":"SECRET-CONTENT"}')" = "/elsewhere/y.go" ]
expect "dash-event: cwd prefix must end at a slash" [ "$(tool_sum Edit '{"file_path":"/rx/a.go","old_string":"SECRET-CONTENT"}')" = "/rx/a.go" ]
expect "dash-event: MultiEdit strips cwd" [ "$(tool_sum MultiEdit '{"file_path":"/r/b.go","edits":[]}')" = "b.go" ]
expect "dash-event: NotebookEdit strips cwd" [ "$(tool_sum NotebookEdit '{"notebook_path":"/r/nb/n.ipynb","new_source":"SECRET-CONTENT"}')" = "nb/n.ipynb" ]
expect "dash-event: Bash first two words" [ "$(tool_sum Bash '{"command":"git status --short"}')" = "git status" ]
expect "dash-event: Bash strips env assignments" [ "$(tool_sum Bash '{"command":"FOO=1 BAR=\"a b\" go test ./... -run X"}')" = "go test" ]
expect "dash-event: Bash strips leading cd <dir> &&" [ "$(tool_sum Bash '{"command":"cd /tmp/x && make test"}')" = "make test" ]
expect "dash-event: Bash strips env then cd" [ "$(tool_sum Bash '{"command":"CI=1 cd \"/tmp/a b\" && go vet ./..."}')" = "go vet" ]
expect "dash-event: Bash summary drops the rest of the command" [ "$(tool_sum Bash '{"command":"echo hello SECRET-COMMAND-TAIL"}')" = "echo hello" ]
s=$(tool_sum Bash '{"command":"node \"/x/grok-build/0.2.1/scripts/grok-bridge.mjs\" run --background --write \"Implement the HTTP middleware for rate limits across every handler in the api package\""}')
expect "dash-event: grok run summary" [ "${s#grok-bridge run }" != "$s" ]
expect "dash-event: grok run carries the brief" grep -q 'Implement the HTTP middleware' <<<"$s"
expect "dash-event: grok summary at most 80 chars" [ "${#s}" -le 80 ]
expect "dash-event: grok marked x" last_ev s1 '.x == "grok"'
expect "dash-event: grok show summary" [ "$(tool_sum Bash '{"command":"node /x/grok-bridge.mjs show r-1"}')" = "grok-bridge show" ]
expect "dash-event: codex exec" [ "$(tool_sum Bash '{"command":"codex exec \"fix the flaky test\""}')" = "codex exec" ]
expect "dash-event: codex marked x" last_ev s1 '.x == "codex"'
expect "dash-event: codex companion" [ "$(tool_sum Bash '{"command":"node \"/p/codex/scripts/codex-companion.mjs\" task --background \"x\""}')" = "codex task" ]
expect "dash-event: codex companion marked x" last_ev s1 '.x == "codex"'
expect "dash-event: codex in a quoted message is not codex" [ "$(tool_sum Bash '{"command":"git commit -m \"codex notes\""}')" = "git commit" ]
expect "dash-event: plain Bash has no x" last_ev s1 'has("x") | not'
expect "dash-event: Grep pattern capped at 40" [ "$(tool_sum Grep "{\"pattern\":\"$long\"}" | awk '{print length}')" = 40 ]
expect "dash-event: Glob pattern" [ "$(tool_sum Glob '{"pattern":"api/**/*.go"}')" = "api/**/*.go" ]
expect "dash-event: WebFetch host only" [ "$(tool_sum WebFetch '{"url":"https://user@docs.example.com:8443/p/SECRET-PATH?q=1","prompt":"SECRET-FETCH-PROMPT"}')" = "docs.example.com" ]
expect "dash-event: WebSearch query capped at 50" [ "$(tool_sum WebSearch "{\"query\":\"$long\"}" | awk '{print length}')" = 50 ]
expect "dash-event: Skill name" [ "$(tool_sum Skill '{"skill":"ogxo-route:routing","args":"SECRET-ARGS"}')" = "ogxo-route:routing" ]
expect "dash-event: other tools have an empty summary" [ "$(tool_sum TodoWrite '{"todos":[{"content":"SECRET-TODO"}]}')" = "" ]
# mcp_name <tool_name>: the n the hook records.
mcp_name() { tool_sum "$1" '{}' >/dev/null; events s1 | jq -r '.[-1].n'; }
expect "dash-event: mcp plugin server shortened" [ "$(mcp_name mcp__plugin_thryx_thryx-ogxo__list_items)" = "thryx-ogxo:list_items" ]
expect "dash-event: mcp claude_ai server shortened" [ "$(mcp_name mcp__claude_ai_Claude_Docs__read)" = "Claude_Docs:read" ]
expect "dash-event: mcp plain server" [ "$(mcp_name mcp__github__get_issue)" = "github:get_issue" ]
expect "dash-event: non-mcp name unchanged" [ "$(mcp_name Read)" = "Read" ]

hk '{"session_id":"s1","hook_event_name":"PostToolUse","tool_name":"Agent","tool_use_id":"tu1","tool_input":{"subagent_type":"ogxo-route:implementer","description":"d1","prompt":"SECRET-AGENT-PROMPT"},"tool_response":{"isAsync":true,"status":"async_launched","agentId":"a2dc","description":"d1","resolvedModel":"claude-opus-5-5","outputFile":"/tmp/SECRET-OUTFILE"}}'
expect "dash-event: launched (background)" last_ev s1 '.e == "launched" and .a == null and .u == "tu1" and .id == "a2dc" and .rm == "claude-opus-5-5" and .d == "d1" and .done == false and .tc == null and .out == null and .ty == "ogxo-route:implementer"'
hk '{"session_id":"s1","hook_event_name":"PostToolUse","tool_name":"Agent","tool_use_id":"tu3","agent_id":"ag1","tool_input":{"subagent_type":"grok-build:grok-delegate","prompt":"SECRET-AGENT-PROMPT"},"tool_response":{"status":"completed","agentId":"a3","agentType":"grok-build:grok-delegate","resolvedModel":"claude-sonnet-5-5","totalDurationMs":11443,"totalTokens":14143,"totalToolUseCount":1,"usage":{"output_tokens":196},"content":[{"type":"text","text":"SECRET-RESULT"}]}}'
expect "dash-event: launched (completed)" last_ev s1 '.e == "launched" and .a == "ag1" and .id == "a3" and .ty == "grok-build:grok-delegate" and .done == true and .tc == 1 and .out == 196 and .rm == "claude-sonnet-5-5"'
hk '{"session_id":"s1","hook_event_name":"PostToolUse","tool_name":"Task","tool_use_id":"tu4","tool_input":{},"tool_response":"SECRET-RESULT"}'
expect "dash-event: launched with non-object response" last_ev s1 '.e == "launched" and .u == "tu4" and .id == null and .rm == null and .done == null and .tc == null and .out == null'
hk '{"session_id":"s1","hook_event_name":"PostToolUse","tool_name":"Bash","tool_use_id":"tb1","agent_id":"ag1","tool_input":{"command":"ls"},"tool_response":{"stdout":"SECRET-OUTPUT"}}'
expect "dash-event: tool_ok event" last_ev s1 '.e == "tool_ok" and .a == "ag1" and .u == "tb1" and .n == "Bash" and (keys | sort) == ["a", "e", "n", "t", "u"]'
hk '{"session_id":"s1","hook_event_name":"PostToolUseFailure","tool_name":"mcp__github__get_issue","tool_use_id":"tb2","tool_input":{},"error":"SECRET-ERROR"}'
expect "dash-event: tool_err event" last_ev s1 '.e == "tool_err" and .a == null and .u == "tb2" and .n == "github:get_issue"'

tr="$tmp/transcript.jsonl"
cat >"$tr" <<'JSONL'
{"type":"user","message":{"content":"SECRET-TRANSCRIPT"}}
{"type":"assistant","message":{"id":"m1","content":[{"type":"thinking","thinking":"x"}],"usage":{"output_tokens":5}}}
{"type":"assistant","message":{"id":"m1","content":[{"type":"text","text":"VERDICT: PASS early"}],"usage":{"output_tokens":40}}}
{"type":"assistant","message":{"content":[{"type":"text","text":"no id"}],"usage":{"output_tokens":7}}}
{"type":"assistant","message":{"id":"m2","content":[{"type":"text","text":"Report\nVERDICT: RISKY"}],"usage":{"output_tokens":60}}}
{"type":"assistant","message":{"id":"m2","content":[{"type":"tool_use","name":"x","input":{}}],"usage":{"output_tokens":60}}}
{"broken
JSONL
hk "$(jq -nc --arg p "$tr" '{session_id:"s1", hook_event_name:"SubagentStop", agent_id:"ag1", agent_type:"ogxo-route:verifier", last_assistant_message:"Checked.\nVERDICT: FAIL", agent_transcript_path:$p}')"
expect "dash-event: sstop verdict from last_assistant_message" last_ev s1 '.e == "sstop" and .id == "ag1" and .ty == "ogxo-route:verifier" and .v == "FAIL"'
expect "dash-event: sstop output tokens counted once per message id" last_ev s1 '.out == 107'
hk "$(jq -nc --arg p "$tr" '{session_id:"s1", hook_event_name:"SubagentStop", agent_id:"ag2", agent_type:"ogxo-route:verifier", agent_transcript_path:$p}')"
expect "dash-event: sstop verdict from the transcript's last text" last_ev s1 '.id == "ag2" and .v == "RISKY" and .out == 107'
hk '{"session_id":"s1","hook_event_name":"SubagentStop","agent_id":"ag3","agent_type":"Explore","last_assistant_message":"done, no verdict"}'
expect "dash-event: sstop without verdict or transcript" last_ev s1 '.id == "ag3" and .v == null and .out == null'
hk "$(jq -nc --arg p "$tmp/missing.jsonl" '{session_id:"s1", hook_event_name:"SubagentStop", agent_id:"ag4", agent_type:"Explore", last_assistant_message:"**VERDICT:** PASS", agent_transcript_path:$p}')"
expect "dash-event: sstop missing transcript, bold verdict" last_ev s1 '.id == "ag4" and .v == "PASS" and .out == null'
big="$tmp/big.jsonl"
printf '%s\n' '{"type":"assistant","message":{"id":"b1","content":[{"type":"text","text":"VERDICT: PASS"}],"usage":{"output_tokens":5}}}' >"$big"
head -c 52428800 /dev/zero >>"$big"
hk "$(jq -nc --arg p "$big" '{session_id:"s1", hook_event_name:"SubagentStop", agent_id:"ag5", agent_type:"Explore", agent_transcript_path:$p}')"
expect "dash-event: transcript over 50 MB is skipped" last_ev s1 '.id == "ag5" and .out == null and .v == null'
rm -f "$big"

mkdir -p "$data/x"
: >"$data/x/on"
hk '{"session_id":"../x","hook_event_name":"Stop"}'
hk '{"session_id":"a/b","hook_event_name":"Stop"}'
hk '{"session_id":"","hook_event_name":"Stop"}'
expect "dash-event: traversal session id rejected" [ ! -e "$data/x/events.js" ]
expect "dash-event: slash session id rejected" [ ! -e "$data/dash/a" ]

expect "dash-event: every hook run exits 0 and prints nothing" [ "$noisy" = 0 ]
expect "dash-event: every line is E(<json>);" bash -c '! grep -vqE "^E\(\{.*\}\);$" "$1"' _ "$data/dash/s1/events.js"
expect "dash-event: no prompt, content, output or transcript text recorded" bash -c '! grep -q "SECRET-" "$1"' _ "$data/dash/s1/events.js"

hk '{"session_id":"s1","hook_event_name":"SessionEnd","reason":"exit"}'
expect "dash-event: end event" last_ev s1 '.e == "end"'
expect "dash-event: SessionEnd removes the flag" [ ! -e "$data/dash/s1/on" ]
n_before=$(lines "$data/dash/s1/events.js")
hk '{"session_id":"s1","hook_event_name":"Stop"}'
expect "dash-event: nothing recorded after SessionEnd" [ "$(lines "$data/dash/s1/events.js")" = "$n_before" ]

# dash.sh
sid=sessABCDEFGH123
# ctl [VAR=value ...] -- <args>: run dash.sh from $tmp (not a git repo); sets $out, $code.
ctl() {
  local envs=()
  while [ "$1" != -- ]; do envs+=("$1"); shift; done
  shift
  out=$(cd "$tmp" && env CLAUDE_PLUGIN_DATA="$data" CLAUDE_CODE_SESSION_ID="$sid" ${envs[@]+"${envs[@]}"} bash "$dctl" "$@" 2>"$tmp/err")
  code=$?
}
reset_data
ctl --
bdir="$data/dash/$sid"
expect "dash.sh: on is the default and exits 0" [ "$code" -eq 0 ]
expect "dash.sh: on line 1" [ "$(sed -n 1p <<<"$out")" = "Route board on for session sessABCD." ]
expect "dash.sh: on line 2 is the board URL" [ "$(sed -n 2p <<<"$out")" = "Open: file://$bdir/index.html" ]
expect "dash.sh: on line 3 names the off command" grep -qF '/ogxo-route:dashboard off' <<<"$(sed -n 3p <<<"$out")"
expect "dash.sh: on prints 3 lines" [ "$(wc -l <<<"$out" | tr -d ' ')" = 3 ]
expect "dash.sh: index.html copied" cmp -s "$plugin/dashboard/index.html" "$bdir/index.html"
expect "dash.sh: flag set" [ -e "$bdir/on" ]
expect "dash.sh: on event" last_ev "$sid" '.e == "on" and .sid == "sessABCDEFGH123" and .branch == "" and (.t | type == "number")'
expect "dash.sh: on event repo is the cwd basename outside git" [ "$(events "$sid" | jq -r '.[-1].repo')" = "$(basename "$tmp")" ]
printf 'stale' >"$bdir/index.html"
ctl -- on
expect "dash.sh: on overwrites index.html" cmp -s "$plugin/dashboard/index.html" "$bdir/index.html"
expect "dash.sh: on appends, never rewrites" [ "$(lines "$bdir/events.js")" = 2 ]
ctl -- status
expect "dash.sh: status on" grep -q 'on' <<<"$out"
expect "dash.sh: status shows the path" grep -qF "$bdir" <<<"$out"

printf '[{"task":"A","writer":"implementer","files":["a.go"],"mode":"shared"},{"task":"B","writer":"grok","files":[],"mode":"worktree"}]' >"$tmp/rows"
ctl -- batch <"$tmp/rows"
expect "dash.sh: batch exit 0" [ "$code" -eq 0 ]
expect "dash.sh: batch event" last_ev "$sid" '.e == "batch" and (.rows | length) == 2 and .rows[0].task == "A" and .rows[1].writer == "grok"'
n_before=$(lines "$bdir/events.js")
for bad in '{"task":"A"}' '[1,2]' 'not json' '' '[{"task":"A"}] [{"task":"B"}]'; do
  printf '%s' "$bad" >"$tmp/rows"
  ctl -- batch <"$tmp/rows"
  expect "dash.sh: batch rejects '$bad' with exit 2" [ "$code" -eq 2 ]
done
expect "dash.sh: rejected batches write nothing" [ "$(lines "$bdir/events.js")" = "$n_before" ]

ctl -- off
expect "dash.sh: off exit 0" [ "$code" -eq 0 ]
expect "dash.sh: off removes the flag" [ ! -e "$bdir/on" ]
expect "dash.sh: off keeps the board files" test -f "$bdir/events.js" -a -f "$bdir/index.html"
ctl -- status
expect "dash.sh: status off" grep -q 'off' <<<"$out"
printf '[{"task":"A","writer":"implementer","files":[],"mode":"shared"}]' >"$tmp/rows"
ctl -- batch <"$tmp/rows"
expect "dash.sh: batch while off exits 0" [ "$code" -eq 0 ]
expect "dash.sh: batch while off prints one line" test -n "$out" -a "$(wc -l <<<"$out" | tr -d ' ')" = 1
expect "dash.sh: batch while off writes nothing" [ "$(lines "$bdir/events.js")" = "$n_before" ]
ctl -- status other2
expect "dash.sh: explicit session id" grep -qF "$data/dash/other2" <<<"$out"

ctl -- demo
expect "dash.sh: demo URL" [ "$out" = "Open: file://$plugin/dashboard/index.html?demo" ]

ctl -- on ../x
expect "dash.sh: traversal session id exit 2" [ "$code" -eq 2 ]
expect "dash.sh: traversal session id writes nothing" [ ! -e "$data/x" ]
ctl -- on 'a b'
expect "dash.sh: bad session id exit 2" [ "$code" -eq 2 ]
ctl -- bogus
expect "dash.sh: unknown action exit 2" [ "$code" -eq 2 ]
expect "dash.sh: unknown action prints usage" grep -q 'usage' "$tmp/err"
ctl -- on s1 extra
expect "dash.sh: extra argument exit 2" [ "$code" -eq 2 ]
out=$(cd "$tmp" && env -u CLAUDE_CODE_SESSION_ID CLAUDE_PLUGIN_DATA="$data" bash "$dctl" on 2>"$tmp/err")
code=$?
expect "dash.sh: no session id exit 2" [ "$code" -eq 2 ]
out=$(env -u CLAUDE_PLUGIN_DATA CLAUDE_CODE_SESSION_ID="$sid" bash "$dctl" on 2>"$tmp/err")
code=$?
expect "dash.sh: no data dir exit 1" [ "$code" -eq 1 ]
expect "dash.sh: no data dir says so" grep -q 'CLAUDE_PLUGIN_DATA' "$tmp/err"
ctl PATH="$nojq" -- on
expect "dash.sh: no jq exit 1" [ "$code" -eq 1 ]
expect "dash.sh: no jq says so" grep -q 'jq' "$tmp/err"

reset_data
d="$data/dash"
mkdir -p "$d/old1" "$d/old2" "$d/oldon" "$d/fresh" "$d/$sid" "$d/bad.name" "$tmp/outside"
for b in old1 oldon fresh "$sid" bad.name; do printf 'E({});\n' >"$d/$b/events.js"; done
: >"$d/oldon/on"
: >"$tmp/outside/keep"
ln -s "$tmp/outside" "$d/link"
for f in "$d/old1/events.js" "$d/oldon/events.js" "$d/$sid/events.js" "$d/bad.name/events.js" "$d/old2" "$tmp/outside"; do touch -t 202001010000 "$f"; done
touch -h -t 202001010000 "$d/link" 2>/dev/null
ctl -- on
expect "dash.sh: prune removes stale boards" [ ! -e "$d/old1" ]
expect "dash.sh: prune removes stale empty board dirs" [ ! -e "$d/old2" ]
expect "dash.sh: prune keeps boards that are on" [ -e "$d/oldon/events.js" ]
expect "dash.sh: prune keeps fresh boards" [ -e "$d/fresh/events.js" ]
expect "dash.sh: prune keeps this session's board" [ -e "$d/$sid/events.js" ]
expect "dash.sh: prune skips names that are not session ids" [ -e "$d/bad.name/events.js" ]
expect "dash.sh: prune leaves symlinks and their targets alone" test -L "$d/link" -a -e "$tmp/outside/keep"

hj="$plugin/hooks/hooks.json"
for ev in UserPromptSubmit PreToolUse PostToolUse PostToolUseFailure SubagentStart SubagentStop Stop SessionEnd; do
  expect "hooks: dash-event.sh registered for $ev" jq -e --arg e "$ev" '[.hooks[$e][]? | .hooks[].command | select(. == "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/dash-event.sh\"")] | length == 1' "$hj"
done
for ev in PreToolUse PostToolUse PostToolUseFailure; do
  expect "hooks: dash-event.sh on $ev matches every tool" jq -e --arg e "$ev" '[.hooks[$e][] | select(.hooks[].command | contains("dash-event.sh")) | .matcher] == ["*"]' "$hj"
done
expect "hooks: no async field" jq -e '[.. | objects | has("async")] | any | not' "$hj"
expect "hooks: existing entries kept first" jq -e '.hooks.PreToolUse[0].matcher == "Agent|Task" and (.hooks.PreToolUse[0].hooks[0].command | contains("generic-warn.sh")) and (.hooks.PostToolUse[0].hooks[0].command | contains("dispatch-log.sh")) and (.hooks.PostToolUse[1].hooks[0].command | contains("quota-watch.sh")) and (.hooks.SessionStart[0].hooks[0].command | contains("anchor.sh"))' "$hj"
expect "hooks: description keeps the guarantees and names the board" jq -e '.description | contains("Warns, never blocks") and contains("Requires jq") and test("board")' "$hj"
cmdf="$plugin/commands/dashboard.md"
expect "command: dashboard runs dash.sh" grep -qF 'CLAUDE_PLUGIN_DATA="${CLAUDE_PLUGIN_DATA}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/dash.sh" $ARGUMENTS' "$cmdf"
expect "command: dashboard allowed-tools" grep -qF 'allowed-tools: Bash(CLAUDE_PLUGIN_DATA=*)' "$cmdf"

page="$plugin/dashboard/index.html"
expect "dashboard: page has one script block" [ "$(grep -c '<script' "$page")" = 1 ]
if command -v node >/dev/null 2>&1; then
  awk '/<script>/{f=1; next} /<\/script>/{f=0} f' "$page" >"$tmp/page.js"
  expect "dashboard: page JavaScript parses" node --check "$tmp/page.js"
else
  echo "SKIP: dashboard page JavaScript check (node not installed)"
fi

# --- dashboard hub and per-session fast path ---
# reg_has <jq filter>: pass when the filter holds for boards.js as one array.
reg_has() { sed -e 's/^B(//' -e 's/);$//' "$data/dash/boards.js" 2>/dev/null | jq -s -e "$1" >/dev/null; }
reset_data
ctl -- on
expect "dash.sh: on copies the hub page" cmp -s "$plugin/dashboard/hub.html" "$data/dash/index.html"
expect "dash.sh: on writes meta.json" jq -e --arg r "$(basename "$tmp")" '.repo == $r and .branch == "" and (.cwd | length > 0)' "$bdir/meta.json"
expect "dash.sh: registry lists the board as on" reg_has 'length == 1 and .[0].sid == "sessABCDEFGH123" and .[0].on == true and (.[0].repo | length > 0)'
expect "dash.sh: on names the hub command" grep -qF '/ogxo-route:dashboard hub' <<<"$out"
ctl -- off
expect "dash.sh: off updates the registry" reg_has '.[0].on == false'
mkdir -p "$data/dash/nometa" "$data/dash/bad.name" "$tmp/outside2"
ln -s "$tmp/outside2" "$data/dash/lnk"
ctl -- hub
expect "dash.sh: hub exit 0" [ "$code" -eq 0 ]
expect "dash.sh: hub prints the hub URL" [ "$out" = "Open: file://$data/dash/index.html" ]
expect "dash.sh: registry lists boards without meta.json" reg_has 'any(.[]; .sid == "nometa" and .on == false)'
expect "dash.sh: registry skips bad names and symlinks" reg_has 'length == 2 and all(.[]; .sid != "bad.name" and .sid != "lnk")'
expect "dash.sh: registry lines are B(...) calls" bash -c '! grep -qv "^B({.*});$" "$1"' _ "$data/dash/boards.js"
expect "dash.sh: registry leaves no temp files" [ "$(ls "$data/dash" | grep -c 'tmp')" = 0 ]
expect "command: dashboard argument hint" grep -qF 'argument-hint: "[on|off|status|hub|demo]"' "$cmdf"
expect "command: dashboard may open the page" grep -qF 'Bash(open:*), Bash(xdg-open:*)' "$cmdf"

# A spy jq on PATH records whether the hook got past its bash checks.
spy="$tmp/spy"
mkdir -p "$spy"
printf '#!/bin/sh\n: >"%s/called"\nexec "%s" "$@"\n' "$spy" "$(command -v jq)" >"$spy/jq"
chmod +x "$spy/jq"
reset_data
board_on other
rm -f "$spy/called"
run_hook "$dash" '{"session_id":"s1","hook_event_name":"Stop"}' PATH="$spy:$PATH"
expect "dash-event: another session's board does not start jq" [ ! -e "$spy/called" ]
expect "dash-event: another session's board, exit 0 silently" test "$code" -eq 0 -a -z "$out"
board_on s1
run_hook "$dash" '{"session_id":"s1","hook_event_name":"Stop"}' PATH="$spy:$PATH"
expect "dash-event: this session's board runs jq" [ -e "$spy/called" ]
expect "dash-event: this session's board records" last_ev s1 '.e == "stop"'
run_hook "$dash" '{"session_id":"s1","hook_event_name":"PreToolUse","tool_name":"Write","tool_use_id":"w9","cwd":"/r","tool_input":{"file_path":"/r/a.json","content":"{\"session_id\":\"other\"}"}}'
expect "dash-event: a session_id inside tool input does not redirect the event" last_ev s1 '.e == "tool" and .u == "w9"'
expect "dash-event: nothing written to the board named in tool input" [ ! -e "$data/dash/other/events.js" ]

# Worktrees: a board started in a linked worktree is named after the main repo.
if command -v git >/dev/null 2>&1; then
  reset_data
  gr="$tmp/mainrepo"
  git init -q "$gr" && git -C "$gr" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  git -C "$gr" worktree add -q "$gr/.claude/worktrees/wt1" -b wt1 2>/dev/null
  out=$(cd "$gr/.claude/worktrees/wt1" && env CLAUDE_PLUGIN_DATA="$data" bash "$dctl" on wtsess 2>"$tmp/err")
  expect "dash.sh: worktree board names the main repo" jq -e '.repo == "mainrepo" and .wt == "wt1" and .branch == "wt1"' "$data/dash/wtsess/meta.json"
  expect "dash.sh: worktree on event carries wt" last_ev wtsess '.repo == "mainrepo" and .wt == "wt1"'
  expect "dash.sh: registry carries wt" reg_has 'any(.[]; .sid == "wtsess" and .wt == "wt1")'
  out=$(cd "$gr" && env CLAUDE_PLUGIN_DATA="$data" bash "$dctl" on mainsess 2>"$tmp/err")
  expect "dash.sh: main checkout has no wt" jq -e '.repo == "mainrepo" and .wt == ""' "$data/dash/mainsess/meta.json"
fi
expect "dashboard: a stop with no start and no type is not a worker" grep -qF "if (!S.byId.has(ev.id) && !ev.ty) break;" "$page"
expect "dashboard: tool calls from an unstarted untyped agent are skipped" grep -qF "if (ev.a && !S.byId.has(ev.a) && !ev.at) break;" "$page"
expect "dashboard: no finished cards when the row is full of running ones" grep -qF "room ? done.slice(-room) : []" "$page"
expect "dashboard: agents are tagged with their worktree" grep -qF '.claude\/worktrees\/([^/\s]+)\/' "$page"
expect "skill: isolated batch rows carry the worktree" grep -qF '"worktree": ".claude/worktrees/<task>"' "$skill"

# --- dashboard: permission waits, advisor calls, drained stdin ---
reset_data
board_on s1
hk '{"session_id":"s1","hook_event_name":"PermissionRequest","agent_id":"ag1","tool_name":"Bash","tool_input":{"command":"SECRET-CMD rm -rf x"},"permission_mode":"default"}'
expect "dash-event: permission request event" last_ev s1 '.e == "perm" and .a == "ag1" and .n == "Bash" and (has("tool_input") | not)'
hk '{"session_id":"s1","hook_event_name":"Notification","notification_type":"permission_prompt","message":"SECRET-MESSAGE Claude needs your permission to use Bash"}'
expect "dash-event: notification event" last_ev s1 '.e == "wait" and .a == null and .k == "permission_prompt"'
expect "dash-event: no command or message text recorded" bash -c '! grep -q "SECRET-" "$1"' _ "$data/dash/s1/events.js"

tr="$tmp/transcript.jsonl"
{
  printf '%s\n' '{"type":"user","message":{"content":"SECRET-PROMPT"}}'
  printf '%s\n' '{"type":"assistant","timestamp":"2026-09-30T15:00:00.123Z","message":{"content":[{"type":"server_tool_use","id":"srvtoolu_A","name":"advisor","input":{}}]}}'
  printf '%s\n' '{"type":"assistant","timestamp":"2026-09-30T15:00:01.000Z","message":{"content":[{"type":"server_tool_use","id":"srvtoolu_A","name":"advisor","input":{}},{"type":"text","text":"x"}]}}'
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"server_tool_use","id":"srvtoolu_W","name":"web_search","input":{}}]}}'
  printf '%s' '{"type":"assistant","message":{"content":[{"type":"server_tool_use","id":"srvtoolu_P","name":"advisor"'
} >"$tr"
adv_count() { events s1 | jq '[.[] | select(.e == "advisor")] | length'; }
hk "$(jq -nc --arg p "$tr" '{session_id:"s1", hook_event_name:"Stop", transcript_path:$p}')"
expect "dash-event: advisor call counted once per id" [ "$(adv_count)" = 1 ]
expect "dash-event: advisor event uses the transcript time" bash -c 'sed -e "s/^E(//" -e "s/);$//" "$1" | jq -s -e "[.[] | select(.e == \"advisor\")][0].t == 1790780400000" >/dev/null' _ "$data/dash/s1/events.js"
expect "dash-event: stop recorded after the advisor scan" last_ev s1 '.e == "stop"'
expect "dash-event: partial last line not consumed" [ "$(cat "$data/dash/s1/adv.off")" -lt "$(wc -c <"$tr" | tr -d ' ')" ]
printf '%s\n' ',"input":{}}]}}' >>"$tr"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"server_tool_use","id":"srvtoolu_A","name":"advisor","input":{}}]}}' >>"$tr"
hk "$(jq -nc --arg p "$tr" '{session_id:"s1", hook_event_name:"PreToolUse", tool_name:"Agent", tool_use_id:"tuA", transcript_path:$p, tool_input:{subagent_type:"ogxo-route:implementer-risky", description:"x"}}')"
expect "dash-event: a main dispatch picks up the completed call, not the repeat" [ "$(adv_count)" = 2 ]
hk "$(jq -nc --arg p "$tr" '{session_id:"s1", hook_event_name:"PreToolUse", tool_name:"Agent", agent_id:"ag1", tool_use_id:"tuB", transcript_path:$p, tool_input:{subagent_type:"Explore", description:"x"}}')"
expect "dash-event: nested dispatches do not scan" [ "$(adv_count)" = 2 ]
expect "dash-event: transcript text never recorded" bash -c '! grep -q "SECRET-PROMPT" "$1"' _ "$data/dash/s1/events.js"
expect "dash-event: advisor scan stays quiet" [ "$noisy" = 0 ]

big_payload() { printf '{"session_id":"s1","hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"content":"'; head -c 300000 /dev/zero | tr '\0' x; printf '"}}'; }
reset_data
big_payload | env CLAUDE_PLUGIN_ROOT="$plugin" CLAUDE_PLUGIN_DATA="$data" bash "$dash"
expect "dash-event: no board, large payload is read, not a broken pipe" [ "${PIPESTATUS[0]}" = 0 ]
big_payload | env -u CLAUDE_PLUGIN_DATA CLAUDE_PLUGIN_ROOT="$plugin" bash "$dash"
expect "dash-event: no data dir, large payload is read" [ "${PIPESTATUS[0]}" = 0 ]
for ev in PermissionRequest Notification; do
  expect "hooks: dash-event.sh registered for $ev" jq -e --arg e "$ev" '[.hooks[$e][]? | .hooks[].command | select(. == "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/dash-event.sh\"")] | length == 1' "$hj"
done
expect "hooks: main's permission hooks kept" jq -e '[.hooks.PermissionRequest[].hooks[].command | select(contains("permission-log.sh"))] | length == 1' "$hj"
expect "dashboard: page shows advisor calls and waits" grep -qF "case 'advisor':" "$page"

hubp="$plugin/dashboard/hub.html"
expect "dashboard: hub has one script block" [ "$(grep -c '<script' "$hubp")" = 1 ]
expect "dashboard: board links to the hub" grep -qF 'href="../index.html"' "$page"
if command -v node >/dev/null 2>&1; then
  awk '/<script>/{f=1; next} /<\/script>/{f=0} f' "$hubp" >"$tmp/hub.js"
  expect "dashboard: hub JavaScript parses" node --check "$tmp/hub.js"
fi

# --- dashboard: token usage ---
reset_data
board_on s1
str="$tmp/sub-usage.jsonl"
{
  # one message split over two lines (usage repeated), one with a 1-hour cache write
  printf '%s\n' '{"type":"assistant","message":{"id":"m1","model":"claude-sonnet-5-5","content":[{"type":"text","text":"a"}],"usage":{"input_tokens":10,"output_tokens":100,"cache_read_input_tokens":1000,"cache_creation_input_tokens":500,"cache_creation":{"ephemeral_5m_input_tokens":500,"ephemeral_1h_input_tokens":0}}}}'
  printf '%s\n' '{"type":"assistant","message":{"id":"m1","model":"claude-sonnet-5-5","content":[{"type":"tool_use","id":"t","name":"Bash","input":{}}],"usage":{"input_tokens":10,"output_tokens":100,"cache_read_input_tokens":1000,"cache_creation_input_tokens":500,"cache_creation":{"ephemeral_5m_input_tokens":500,"ephemeral_1h_input_tokens":0}}}}'
  printf '%s\n' '{"type":"assistant","message":{"id":"m2","model":"claude-sonnet-5-5","content":[{"type":"text","text":"b"}],"usage":{"input_tokens":5,"output_tokens":50,"cache_read_input_tokens":2000,"cache_creation_input_tokens":300,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":300}}}}'
} >"$str"
hk "$(jq -nc --arg p "$str" '{session_id:"s1", hook_event_name:"SubagentStop", agent_id:"ag9", agent_type:"ogxo-route:implementer", agent_transcript_path:$p}')"
expect "dash-event: worker usage summed once per message, by model" last_ev s1 '.e == "sstop" and .use["claude-sonnet-5-5"] == {in: 15, out: 150, cr: 3000, cw5: 500, cw1: 300}'

mtr="$tmp/main-usage.jsonl"
{
  printf '%s\n' '{"type":"user","message":{"content":"SECRET-PROMPT"}}'
  # the advisor ran inside this message: its iteration carries its own model
  printf '%s\n' '{"type":"assistant","message":{"id":"x1","model":"claude-opus-5-5","content":[{"type":"text","text":"a"}],"usage":{"input_tokens":4,"output_tokens":809,"cache_read_input_tokens":192259,"cache_creation_input_tokens":2546,"iterations":[{"type":"message","input_tokens":2,"output_tokens":553,"cache_read_input_tokens":95895,"cache_creation_input_tokens":469,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":469}},{"type":"advisor_message","model":"claude-fable-5-1","input_tokens":98505,"output_tokens":4867,"cache_read_input_tokens":0,"cache_creation_input_tokens":0},{"type":"message","input_tokens":2,"output_tokens":256,"cache_read_input_tokens":96364,"cache_creation_input_tokens":2077,"cache_creation":{"ephemeral_5m_input_tokens":2077,"ephemeral_1h_input_tokens":0}}]}}}'
  printf '%s\n' '{"type":"assistant","message":{"id":"x2","model":"claude-opus-5-5","content":[{"type":"text","text":"b"}],"usage":{"input_tokens":1,"output_tokens":10,"cache_read_input_tokens":100,"cache_creation_input_tokens":0}}}'
} >"$mtr"
use_evs() { events s1 | jq -c '[.[] | select(.e == "use") | .use]'; }
hk "$(jq -nc --arg p "$mtr" '{session_id:"s1", hook_event_name:"Stop", transcript_path:$p}')"
got=$(use_evs | jq -c '.[0]')
expect "dash-event: main usage from each iteration, advisor apart" [ "$got" = '{"claude-opus-5-5":{"in":5,"out":819,"cr":192359,"cw5":2077,"cw1":469},"adv:claude-fable-5-1":{"in":98505,"out":4867,"cr":0,"cw5":0,"cw1":0}}' ]
printf '%s\n' '{"type":"assistant","message":{"id":"x2","model":"claude-opus-5-5","content":[{"type":"tool_use","id":"t","name":"Bash","input":{}}],"usage":{"input_tokens":1,"output_tokens":10,"cache_read_input_tokens":100,"cache_creation_input_tokens":0}}}' >>"$mtr"
printf '%s\n' '{"type":"assistant","message":{"id":"x3","model":"claude-opus-5-5","content":[{"type":"text","text":"c"}],"usage":{"input_tokens":2,"output_tokens":20,"cache_read_input_tokens":200,"cache_creation_input_tokens":0}}}' >>"$mtr"
hk "$(jq -nc --arg p "$mtr" '{session_id:"s1", hook_event_name:"Stop", transcript_path:$p}')"
got=$(use_evs | jq -c '.[1]')
expect "dash-event: next scan counts only new messages, not the repeated last one" [ "$got" = '{"claude-opus-5-5":{"in":2,"out":20,"cr":200,"cw5":0,"cw1":0}}' ]
hk "$(jq -nc --arg p "$mtr" '{session_id:"s1", hook_event_name:"Stop", transcript_path:$p}')"
expect "dash-event: nothing new, no use event" [ "$(use_evs | jq length)" = 2 ]
expect "dash-event: usage scan records no transcript text" bash -c '! grep -q "SECRET-PROMPT" "$1"' _ "$data/dash/s1/events.js"
expect "dash-event: usage scan stays quiet" [ "$noisy" = 0 ]

prices() { grep -A7 '^  const PRICES = \[' "$1"; }
pa=$(prices "$page"); pb=$(prices "$hubp")
expect "dashboard: page has a price table" [ -n "$pa" ]
expect "dashboard: board and hub use the same price table" [ "$pa" = "$pb" ]
expect "dashboard: page ingests token usage" grep -qF "case 'use':" "$page"
expect "dashboard: hub skips helper stops for cost too" grep -qF "if (ev.ty || started.has(ev.id)) addCost(ev.use);" "$hubp"
if command -v node >/dev/null 2>&1; then
  awk '/const PRICES = \[/{f=1} f{print} /const costOf = /{c=1} c&&/^  };$/{exit}' "$page" >"$tmp/prices.js"
  printf '%s\n' 'const r = [costOf({in: 1e6}, "claude-opus-5-5"), costOf({cw1: 1e6}, "claude-opus-5-5"), costOf({cr: 1e6}, "claude-haiku-4-5-20251001"), costOf({out: 1e6}, "claude-fable-5-1"), costOf({in: 1}, "gpt-x")];' 'process.stdout.write(JSON.stringify(r));' >>"$tmp/prices.js"
  expect "dashboard: prices by model prefix, 1-hour writes at 2x, unknown model has no price" bash -c '[ "$(node "$1")" = "[4,8,0.1,50,null]" ]' _ "$tmp/prices.js"
fi

echo "route tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

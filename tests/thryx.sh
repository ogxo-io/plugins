#!/usr/bin/env bash
# Tests for plugins/thryx/scripts/connect.sh against stubs of `claude`,
# `codex`, `security`, and `osascript` that record every call. PATH holds only the
# stubs and the tools the script needs, so the real Keychain, dialogs, and
# Claude Code config are never touched.
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
script="$root/plugins/thryx/scripts/connect.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
expect() {
  local desc=$1
  shift
  if "$@" >/dev/null 2>&1; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $desc"; fi
}

sys="$tmp/sys"
mkdir -p "$sys"
for b in bash sh env jq cat grep mv head paste; do
  p=$(command -v "$b") && ln -sf "$p" "$sys/$b"
done

stubs="$tmp/stubs"
mkdir -p "$stubs"
# claude mcp get|remove <name>; claude mcp add-json --scope user <name> <json>
cat >"$stubs/claude" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "claude $*" >>"$STUB_DIR/calls"
case "$1 $2" in
  "mcp get") grep -qxF "$3" "$STUB_DIR/servers" ;;
  "mcp remove") grep -vxF "$3" "$STUB_DIR/servers" >"$STUB_DIR/s.tmp"; mv "$STUB_DIR/s.tmp" "$STUB_DIR/servers" ;;
  "mcp add-json") printf '%s\n' "$6" >"$STUB_DIR/json"; printf '%s\n' "$5" >>"$STUB_DIR/servers" ;;
esac
STUB
# Codex stores the variable name, not a headers helper or token.
cat >"$stubs/codex" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "codex $*" >>"$STUB_DIR/calls"
case "$1 $2" in
  "mcp get") grep -qxF "$3" "$STUB_DIR/servers" ;;
  "mcp add") [ -z "${CODEX_ADD_FAIL:-}" ] || exit 1; printf '%s\n' "$*" >"$STUB_DIR/codex-config" ;;
esac
STUB
# security find-generic-password -s S -a A [-w]; add-generic-password -U -s S -a A -l L -w T
cat >"$stubs/security" <<'STUB'
#!/usr/bin/env bash
cmd=$1; shift
s=""; a=""; w=""; wflag=false
while [ $# -gt 0 ]; do
  case $1 in
    -s) s=$2; shift 2 ;;
    -a) a=$2; shift 2 ;;
    -l) shift 2 ;;
    -w) wflag=true; if [ $# -ge 2 ]; then w=$2; shift 2; else shift; fi ;;
    *) shift ;;
  esac
done
printf '%s\n' "security $cmd -s $s -a $a" >>"$STUB_DIR/calls"
case $cmd in
  find-generic-password) v=$(grep -F "$s/$a=" "$STUB_DIR/kc" 2>/dev/null | head -1) || exit 44; [ -n "$v" ] || exit 44; $wflag && printf '%s\n' "${v#*=}"; exit 0 ;;
  add-generic-password) { grep -vF "$s/$a=" "$STUB_DIR/kc" 2>/dev/null; printf '%s\n' "$s/$a=$w"; } >"$STUB_DIR/kc.tmp"; mv "$STUB_DIR/kc.tmp" "$STUB_DIR/kc" ;;
esac
STUB
# osascript: prints $DIALOG_ANSWER, or exits 1 (Cancel) when it is empty.
cat >"$stubs/osascript" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "osascript dialog" >>"$STUB_DIR/calls"
[ -n "${DIALOG_ANSWER:-}" ] || exit 1
printf '%s\n' "$DIALOG_ANSWER"
STUB
chmod +x "$stubs"/*
envmode="$tmp/envmode"
mkdir -p "$envmode"
ln -sf "$stubs/claude" "$envmode/claude"

# run <mode: keychain|env> <VAR=value ...> -- <args...>: sets $out and $code.
# SEED_SERVERS and SEED_KC preload the stubs' state.
run() {
  local mode=$1
  shift
  rm -rf "$tmp/stub"
  mkdir -p "$tmp/stub"
  : >"$tmp/stub/calls"
  printf '%s' "${SEED_SERVERS:-}" >"$tmp/stub/servers"
  printf '%s' "${SEED_KC:-}" >"$tmp/stub/kc"
  local envs=()
  while [ "$1" != -- ]; do envs+=("$1"); shift; done
  shift
  local path="$stubs:$sys"
  [ "$mode" = env ] && path="$envmode:$sys"
  out=$(env -i HOME="$tmp" PATH="$path" STUB_DIR="$tmp/stub" "${envs[@]+"${envs[@]}"}" bash "$script" "$@" 2>&1)
  code=$?
}
called() { grep -q "$1" "$tmp/stub/calls"; }
export tmp stubs sys
helper_out() { # run the stored helper with the stubs and print the header
  env -i PATH="$stubs:$sys" STUB_DIR="$tmp/stub" "$@" sh -c "$(jq -r .headersHelper "$tmp/stub/json")" | jq -r .Authorization
}
export -f helper_out

# --- keychain mode (macOS) ---
run keychain DIALOG_ANSWER=tok-shared -- ogxo
expect "keychain: exit 0" [ "$code" -eq 0 ]
expect "keychain: asks with a dialog when no token is stored" called "osascript dialog"
expect "keychain: stores the token under the shared account" grep -qx "thryx-mcp/shared=tok-shared" "$tmp/stub/kc"
expect "keychain: adds a user-scope server thryx-<workspace>" called "claude mcp add-json --scope user thryx-ogxo"
expect "keychain: workspace URL, no static headers" jq -e '.type == "http" and .url == "https://app.thryx.io/api/v1/mcp/ogxo" and (has("headers") | not)' "$tmp/stub/json"
expect "keychain: helper reads the Keychain" bash -c '[ "$(helper_out)" = "Bearer tok-shared" ]'
expect "keychain: token never in config, calls to claude, or output" bash -c '! grep -q tok-shared "$1/stub/json" && ! grep "^claude" "$1/stub/calls" | grep -q tok-shared && ! grep -q tok-shared <<<"$2"' _ "$tmp" "$out"

SEED_KC=$'thryx-mcp/shared=tok-old\n' run keychain DIALOG_ANSWER=unused -- klever
expect "keychain: a stored token is reused without a dialog" bash -c '! grep -q "osascript" "$1/stub/calls"' _ "$tmp"
expect "keychain: second workspace shares the token" bash -c '[ "$(helper_out)" = "Bearer tok-old" ]'

SEED_KC=$'thryx-mcp/shared=tok-old\n' run keychain DIALOG_ANSWER=tok-own -- klever --own-token
expect "own-token: asks and stores under the workspace account" grep -qx "thryx-mcp/klever=tok-own" "$tmp/stub/kc"
expect "own-token: helper reads the workspace's own item" bash -c '[ "$(helper_out)" = "Bearer tok-own" ]'

SEED_KC=$'thryx-mcp/shared=tok-old\n' SEED_SERVERS=$'thryx-ogxo\n' run keychain DIALOG_ANSWER=tok-new -- ogxo --set-token
expect "set-token: asks again and replaces the stored token" grep -qx "thryx-mcp/shared=tok-new" "$tmp/stub/kc"
expect "set-token: existing server kept" bash -c '! grep -q "add-json\|mcp remove" "$1/stub/calls"' _ "$tmp"
expect "set-token: says to reconnect" grep -q "reconnect it from /mcp" <<<"$out"

run keychain -- ogxo
expect "dialog cancelled: exit 1" [ "$code" -eq 1 ]
expect "dialog cancelled: nothing stored or added" bash -c '[ ! -s "$1/stub/kc" ] && ! grep -q add-json "$1/stub/calls"' _ "$tmp"

# --- environment-variable mode ---
run env -- ogxo
expect "env: unset token exits 1" [ "$code" -eq 1 ]
expect "env: says how to set it" grep -qF "export THRYX_TOKEN='<your token>'" <<<"$out"
expect "env: unset token adds nothing" bash -c '! grep -q add-json "$1/stub/calls"' _ "$tmp"

run env THRYX_TOKEN=secret-abc -- ogxo
expect "env: exit 0" [ "$code" -eq 0 ]
expect "env: helper reads THRYX_TOKEN" bash -c '[ "$(helper_out THRYX_TOKEN=t-1)" = "Bearer t-1" ]'
expect "env: token never in config or output" bash -c '! grep -q secret-abc "$1/stub/json" && ! grep -q secret-abc <<<"$2"' _ "$tmp" "$out"

run keychain THRYX_TOKEN_KLEVER=k -- klever --token-var THRYX_TOKEN_KLEVER
expect "token-var: environment mode even where the Keychain exists" bash -c '! grep -q "^security\|osascript" "$1/stub/calls"' _ "$tmp"
expect "token-var: helper reads that variable" bash -c '[ "$(helper_out THRYX_TOKEN_KLEVER=k2)" = "Bearer k2" ]'

# --- existing servers and bad input ---
SEED_SERVERS=$'thryx-ogxo\n' run env THRYX_TOKEN=s -- ogxo
expect "existing: exit 0 and not replaced" bash -c '[ "$2" -eq 0 ] && ! grep -q "add-json\|mcp remove" "$1/stub/calls"' _ "$tmp" "$code"
expect "existing: suggests --replace" grep -qF -- "--replace" <<<"$out"

SEED_SERVERS=$'thryx-ogxo\n' run env THRYX_TOKEN=s -- ogxo --replace
expect "replace: removes, then adds" bash -c '[ "$(grep -oE "mcp (remove|add-json)" "$1/stub/calls" | paste -sd, -)" = "mcp remove,mcp add-json" ]' _ "$tmp"

run env THRYX_TOKEN=s -- 'bad slug;rm'
expect "bad slug: exit 2" [ "$code" -eq 2 ]
run env THRYX_TOKEN=s -- ogxo --token-var 'x;y'
expect "bad variable name: exit 2" [ "$code" -eq 2 ]
run env THRYX_TOKEN=s --
expect "no workspace: exit 2, nothing called" bash -c '[ "$2" -eq 2 ] && [ ! -s "$1/stub/calls" ]' _ "$tmp" "$code"

# --- Codex: environment references, including on macOS ---
run keychain -- ogxo --client codex
expect "codex: registers even before token is set" [ "$code" -eq 0 ]
expect "codex: workspace URL and bearer variable" grep -qxF 'mcp add thryx-ogxo --url https://app.thryx.io/api/v1/mcp/ogxo --bearer-token-env-var THRYX_TOKEN' "$tmp/stub/codex-config"
expect "codex: no Claude or Keychain calls" bash -c '! grep -qE "^(claude|security|osascript) " "$1/stub/calls"' _ "$tmp"
expect "codex: explains environment setup" grep -qF 'THRYX_TOKEN' <<<"$out"
run keychain THRYX_TOKEN_KLEVER=secret-codex -- klever --client codex --token-var THRYX_TOKEN_KLEVER
expect "codex: custom variable" grep -qF -- '--bearer-token-env-var THRYX_TOKEN_KLEVER' "$tmp/stub/codex-config"
expect "codex: no token in output or registration" bash -c '! grep -q secret-codex "$1/stub/calls" && ! grep -q secret-codex <<<"$2"' _ "$tmp" "$out"
SEED_SERVERS=$'thryx-ogxo\n' run keychain -- ogxo --client codex
expect "codex: preserves an existing server" bash -c '[ "$2" -eq 0 ] && ! grep -q "mcp add" "$1/stub/calls"' _ "$tmp" "$code"
SEED_SERVERS=$'thryx-ogxo\n' run keychain -- ogxo --client codex --replace
expect "codex: replaces by adding without removing first" bash -c '[ "$2" -eq 0 ] && grep -q "codex mcp add" "$1/stub/calls" && ! grep -q "mcp remove" "$1/stub/calls"' _ "$tmp" "$code"
run keychain CODEX_ADD_FAIL=1 -- ogxo --client codex
expect "codex: reports registration failure" [ "$code" -eq 1 ]
for flag in --own-token --set-token; do
  run keychain -- ogxo --client codex "$flag"
  expect "codex: rejects $flag before any calls" bash -c '[ "$2" -eq 2 ] && [ ! -s "$1/stub/calls" ]' _ "$tmp" "$code"
done
run keychain -- ogxo --client unknown
expect "unknown client: rejects before any calls" bash -c '[ "$2" -eq 2 ] && [ ! -s "$1/stub/calls" ]' _ "$tmp" "$code"

echo "thryx tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

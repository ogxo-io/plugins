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
for b in bash sh env jq cat grep mv head paste python3 dirname; do
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
# Codex writes a canonical TOML entry, as mcp add does in the real CLI.
cat >"$stubs/codex" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "codex $*" >>"$STUB_DIR/calls"
case "$1 $2" in
  "mcp get") grep -qxF "$3" "$STUB_DIR/servers" ;;
  "mcp add")
    [ -z "${CODEX_ADD_FAIL:-}" ] || exit 1
    printf '%s\n' "$*" >"$STUB_DIR/codex-config"
    python3 - "$3" "$5" <<'PYCONFIG'
import os, pathlib, re, sys
home = pathlib.Path(os.environ.get("CODEX_HOME", str(pathlib.Path.home() / ".codex")))
home.mkdir(parents=True, exist_ok=True)
p = home / "config.toml"
s = p.read_text() if p.exists() else ""
s = re.sub(r"(?ms)^\[mcp_servers\." + re.escape(sys.argv[1]) + r"\]\n.*?(?=^\[|\Z)", "", s)
p.write_text(s.rstrip() + "\n\n[mcp_servers." + sys.argv[1] + ']\nurl = "' + sys.argv[2] + '"\n')
PYCONFIG
    ;;

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
ln -sf "$stubs/codex" "$envmode/codex"

# run <mode: keychain|env> <VAR=value ...> -- <args...>: sets $out and $code.
# SEED_SERVERS and SEED_KC preload the stubs' state.
run() {
  local mode=$1
  shift
  rm -rf "$tmp/stub"
  mkdir -p "$tmp/stub/codex-home"
  printf '%s' "${SEED_CONFIG:-}" >"$tmp/stub/codex-home/config.toml"
  : >"$tmp/stub/calls"
  printf '%s' "${SEED_SERVERS:-}" >"$tmp/stub/servers"
  printf '%s' "${SEED_KC:-}" >"$tmp/stub/kc"
  local envs=()
  while [ "$1" != -- ]; do envs+=("$1"); shift; done
  shift
  local path="$stubs:$sys"
  [ "$mode" = env ] && path="$envmode:$sys"
  out=$(env -i HOME="$tmp" PATH="$path" STUB_DIR="$tmp/stub" CODEX_HOME="$tmp/stub/codex-home" "${envs[@]+"${envs[@]}"}" bash "$script" "$@" 2>&1)
  code=$?
}
called() { grep -q "$1" "$tmp/stub/calls"; }
export tmp stubs sys
helper_out() { # run the stored helper with the stubs and print the header
  env -i PATH="$stubs:$sys" STUB_DIR="$tmp/stub" "$@" sh -c "$(jq -r .headersHelper "$tmp/stub/json")" | jq -r .Authorization
}
codex_helper_out() {
  env -i PATH="$stubs:$sys" STUB_DIR="$tmp/stub" python3 - "$tmp/stub/codex-home/config.toml" "${1:-ogxo}" <<'PYHELPER'
import json, pathlib, subprocess, sys, tomllib
server = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())["mcp_servers"]["thryx-" + sys.argv[2]]
assert "bearer_token_env_var" not in server
assert server["url"] == "https://app.thryx.io/api/v1/mcp/" + sys.argv[2]
result = subprocess.run(server["http_headers_helper"], shell=True, check=True, text=True, capture_output=True)
print(json.loads(result.stdout)["Authorization"])
PYHELPER
}
export -f helper_out codex_helper_out

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

# --- Codex: Keychain by default on macOS ---
run keychain DIALOG_ANSWER=tok-codex -- ogxo --client codex
expect "codex keychain: exit 0" [ "$code" -eq 0 ]
expect "codex keychain: helper authenticates without token environment" bash -c '[ "$(codex_helper_out)" = "Bearer tok-codex" ]'
expect "codex keychain: no token in config or output" bash -c '! grep -q tok-codex "$1/stub/codex-home/config.toml" && ! grep -q tok-codex <<<"$2"' _ "$tmp" "$out"
SEED_KC=$'thryx-mcp/shared=tok-shared\n' run keychain -- ogxo --client codex
expect "codex keychain: reuses the shared token without a dialog" bash -c '[ "$2" -eq 0 ] && ! grep -q osascript "$1/stub/calls" && [ "$(codex_helper_out)" = "Bearer tok-shared" ]' _ "$tmp" "$code"
run keychain DIALOG_ANSWER=tok-own -- klever --client codex --own-token
expect "codex keychain: workspace token" bash -c '[ "$1" -eq 0 ] && [ "$(codex_helper_out klever)" = "Bearer tok-own" ]' _ "$code"
SEED_SERVERS=$'thryx-ogxo\n' run keychain -- ogxo --client codex
expect "codex keychain: preserves existing entry without asking for token" bash -c '[ "$2" -eq 0 ] && ! grep -qE "mcp add|security|osascript" "$1/stub/calls"' _ "$tmp" "$code"
SEED_SERVERS=$'thryx-ogxo\n' SEED_KC=$'thryx-mcp/shared=tok-old\n' run keychain DIALOG_ANSWER=tok-new -- ogxo --client codex --set-token
expect "codex keychain: rotation updates Keychain without replacing config" bash -c '[ "$2" -eq 0 ] && grep -qx "thryx-mcp/shared=tok-new" "$1/stub/kc" && ! grep -q "mcp add" "$1/stub/calls"' _ "$tmp" "$code"
SEED_CONFIG=$'model = "test-model"\n\n[mcp_servers.other]\nurl = "https://example.com/mcp"\n\n[mcp_servers.thryx-ogxo]\nurl = "https://old.example/mcp"\nbearer_token_env_var = "OLD_TOKEN"\n' SEED_SERVERS=$'thryx-ogxo\n' SEED_KC=$'thryx-mcp/shared=tok-replaced\n' run keychain -- ogxo --client codex --replace
expect "codex keychain: replaces old authentication" bash -c '[ "$1" -eq 0 ] && [ "$(codex_helper_out)" = "Bearer tok-replaced" ]' _ "$code"
expect "codex keychain: preserves unrelated configuration" python3 -c 'import pathlib, sys, tomllib; c=tomllib.loads(pathlib.Path(sys.argv[1]).read_text()); assert c["model"] == "test-model"; assert c["mcp_servers"]["other"]["url"] == "https://example.com/mcp"' "$tmp/stub/codex-home/config.toml"
SEED_KC=$'thryx-mcp/shared=token-"quoted"\\slash\n' run keychain -- ogxo --client codex
expect "codex keychain: escapes token as JSON" bash -c '[ "$(codex_helper_out)" = "$1" ]' _ 'Bearer token-"quoted"\slash'
: >"$tmp/stub/kc"
expect "codex keychain: missing credential fails rather than emitting an empty bearer" bash -c '! codex_helper_out'
SEED_CONFIG=$'model = "unchanged"\n' run keychain DIALOG_ANSWER=tok-codex CODEX_ADD_FAIL=1 -- ogxo --client codex
expect "codex keychain: registration failure preserves config" bash -c '[ "$2" -eq 1 ] && [ "$(cat "$1/stub/codex-home/config.toml")" = "$3" ]' _ "$tmp" "$code" 'model = "unchanged"'
run keychain -- ogxo --client codex
expect "codex keychain: cancellation adds nothing" bash -c '[ "$2" -eq 1 ] && ! grep -q "mcp add" "$1/stub/calls"' _ "$tmp" "$code"

# --- Codex: environment references as an explicit option or without Keychain ---
run env -- ogxo --client codex
expect "codex env: registers even before token is set" [ "$code" -eq 0 ]
expect "codex env: workspace URL and bearer variable" grep -qxF 'mcp add thryx-ogxo --url https://app.thryx.io/api/v1/mcp/ogxo --bearer-token-env-var THRYX_TOKEN' "$tmp/stub/codex-config"
run keychain THRYX_TOKEN_KLEVER=secret-codex -- klever --client codex --token-var THRYX_TOKEN_KLEVER
expect "codex env: custom variable bypasses Keychain" bash -c 'grep -qF -- "--bearer-token-env-var THRYX_TOKEN_KLEVER" "$1/stub/codex-config" && ! grep -qE "^(security|osascript) " "$1/stub/calls"' _ "$tmp"
expect "codex env: no token in output or registration" bash -c '! grep -q secret-codex "$1/stub/calls" && ! grep -q secret-codex <<<"$2"' _ "$tmp" "$out"
SEED_SERVERS=$'thryx-ogxo\n' run env -- ogxo --client codex
expect "codex env: preserves an existing server" bash -c '[ "$2" -eq 0 ] && ! grep -q "mcp add" "$1/stub/calls"' _ "$tmp" "$code"
SEED_SERVERS=$'thryx-ogxo\n' run env -- ogxo --client codex --replace
expect "codex env: replaces without removing first" bash -c '[ "$2" -eq 0 ] && grep -q "codex mcp add" "$1/stub/calls" && ! grep -q "mcp remove" "$1/stub/calls"' _ "$tmp" "$code"
run env CODEX_ADD_FAIL=1 -- ogxo --client codex
expect "codex env: reports registration failure" [ "$code" -eq 1 ]
for flag in --own-token --set-token; do
  run env -- ogxo --client codex "$flag"
  expect "codex env: rejects $flag before any calls" bash -c '[ "$2" -eq 2 ] && [ ! -s "$1/stub/calls" ]' _ "$tmp" "$code"
done
run keychain -- ogxo --client unknown
expect "unknown client: rejects before any calls" bash -c '[ "$2" -eq 2 ] && [ ! -s "$1/stub/calls" ]' _ "$tmp" "$code"

echo "thryx tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

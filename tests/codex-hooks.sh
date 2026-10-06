#!/usr/bin/env bash
# Exercise the exported Codex commands with native tool payloads.
set -uo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
pass=0
fail=0
command_for() {
  jq -er --arg label "$2" '[.hooks[][].hooks[] | select(.command | contains($label))][0].command' "$1"
}
check() {
  local got
  bash -c "$3" <"$tmp/payload" >"$tmp/output" 2>&1
  got=$?
  if [ "$got" -eq "$1" ]; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    echo "FAIL: $2 (expected $1, got $got)"
    cat "$tmp/output"
  fi
}
patch_payload() {
  jq -n --arg c "$1" --arg cwd "$tmp" '{tool_name:"apply_patch",cwd:$cwd,tool_input:{command:$c}}' >"$tmp/payload"
}
guards="$root/plugins/ogxo-guards"
format="$root/plugins/ogxo-format"
for plugin in "$guards" "$format"; do
  hooks=$(jq -er '.hooks' "$plugin/.codex-plugin/plugin.json")
  [ -f "$plugin/$hooks" ] || exit 1
done
export PLUGIN_ROOT="$guards"
unset CLAUDE_PLUGIN_ROOT
protect=$(command_for "$guards/hooks/codex-hooks.json" 'ogxo-guards/file-protection')
size=$(command_for "$guards/hooks/codex-hooks.json" 'ogxo-guards/large-file-guard')
staging=$(command_for "$guards/hooks/codex-hooks.json" 'ogxo-guards/env-file-guard')
# Codex reports exec_command to hooks as tool_name Bash with tool_input.command.
jq -n --arg cwd "$tmp" '{tool_name:"Bash",cwd:$cwd,tool_input:{command:"git add .env"}}' >"$tmp/payload"
check 2 'Codex exec_command as Bash command' "$staging"
# Both plugins carry the parser; the copies must not drift.
if cmp -s "$guards/hooks/patch-files.jq" "$format/hooks/patch-files.jq"; then
  pass=$((pass + 1))
else
  fail=$((fail + 1)); echo 'FAIL: patch-files.jq copies differ'
fi
# Codex intercepts heredoc apply_patch sent through exec_command (Bash matcher).
bash_guard() {
  jq -er --arg mode "$1" '[.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[].command
    | select(contains("file-guard.sh\" " + $mode))][0]' "$guards/hooks/codex-hooks.json"
}
for mode in paths size; do
  if bash_guard "$mode" >/dev/null; then pass=$((pass + 1)); else
    fail=$((fail + 1)); echo "FAIL: no file-guard $mode hook on the Codex Bash matcher"
  fi
done
shell_protect=$(bash_guard paths) || shell_protect=false
shell_size=$(bash_guard size) || shell_size=false
shell_payload() {
  jq -n --arg c "$1" --arg cwd "$tmp" '{tool_name:"Bash",cwd:$cwd,tool_input:{command:$c}}' >"$tmp/payload"
}
shell_payload "apply_patch <<'EOF'
*** Begin Patch
*** Add File: package-lock.json
+{}
*** End Patch
EOF"
check 2 'heredoc apply_patch lockfile' "$shell_protect"
shell_payload 'applypatch <<EOF
*** Begin Patch
*** Delete File: yarn.lock
*** End Patch
EOF'
check 2 'heredoc applypatch, unquoted delimiter' "$shell_protect"
shell_payload "cd node_modules && apply_patch <<'EOF'
*** Begin Patch
*** Update File: pkg/index.js
@@
-a
+b
*** End Patch
EOF"
check 2 'cd <dir> && apply_patch resolves against the cd dir' "$shell_protect"
shell_payload "cd \"vendor\" && apply_patch <<\"EOF\"
*** Begin Patch
*** Add File: a.go
+package a
*** End Patch
EOF"
check 2 'cd "<dir>" && apply_patch' "$shell_protect"
shell_payload "cd '$tmp/node_modules' && apply_patch <<'EOF'
*** Begin Patch
*** Add File: a.js
+x
*** End Patch
EOF"
check 2 "cd '<absolute dir>' && apply_patch" "$shell_protect"
shell_payload "cd src && apply_patch <<'EOF'
*** Begin Patch
*** Add File: a.js
+x
*** End Patch
EOF"
check 0 'heredoc apply_patch on a safe path' "$shell_protect"
# Forms Codex's tree-sitter query also accepts: line continuations in the
# prefix and assignment words before cd or apply_patch.
lock_patch="*** Begin Patch
*** Add File: yarn.lock
+x
*** End Patch
EOF"
nm_patch="*** Begin Patch
*** Add File: x.js
+x
*** End Patch
EOF"
shell_payload "apply_patch \\
<<'EOF'
$lock_patch"
check 2 'continuation before <<' "$shell_protect"
shell_payload "applypatch\\
 <<EOF
$lock_patch"
check 2 'continuation right after applypatch' "$shell_protect"
shell_payload "cd node_modules \\
&& apply_patch <<'EOF'
$nm_patch"
check 2 'continuation before &&' "$shell_protect"
shell_payload "cd node_modules &&\\
 apply_patch <<'EOF'
$nm_patch"
check 2 'continuation after &&' "$shell_protect"
shell_payload "cd \\
node_modules && apply_patch <<'EOF'
$nm_patch"
check 2 'continuation after cd' "$shell_protect"
shell_payload "LC_ALL=C apply_patch <<'EOF'
$lock_patch"
check 2 'assignment before apply_patch' "$shell_protect"
shell_payload "A=1 B='x y' apply_patch <<'EOF'
$lock_patch"
check 2 'two assignments before apply_patch' "$shell_protect"
shell_payload "cd node_modules && FOO=1 apply_patch <<'EOF'
$nm_patch"
check 2 'cd <dir> && assignment apply_patch' "$shell_protect"
shell_payload "FOO=1 cd node_modules && apply_patch <<'EOF'
$nm_patch"
check 2 'assignment cd <dir> && apply_patch' "$shell_protect"
shell_payload "cd a\\ b && apply_patch <<'EOF'
$lock_patch"
check 2 'cd with an escaped space' "$shell_protect"
# A body line ending in a backslash must not hide the next header.
shell_payload "apply_patch <<'EOF'
*** Begin Patch
*** Add File: a.txt
+ends with \\
*** Add File: yarn.lock
+x
*** End Patch
EOF"
check 2 'body line ending in a backslash' "$shell_protect"
shell_payload 'cat package-lock.json && rm -rf node_modules/x'
check 0 'ordinary shell command yields no paths' "$shell_protect"
check 0 'ordinary shell command has no size' "$shell_size"
python3 - <<'PY' >"$tmp/payload"
import json
body = "apply_patch <<'EOF'\n*** Begin Patch\n*** Add File: big.txt\n+" + 'x' * 1048576 + "\n*** End Patch\nEOF"
print(json.dumps({'tool_name': 'Bash', 'tool_input': {'command': body}}))
PY
check 2 'oversized heredoc apply_patch' "$shell_size"
# Codex trims header lines (Unicode whitespace, CR) before matching them.
nbsp=$(printf '\302\240')
patch_payload "$(printf '*** Begin Patch\n*** Update File: package-lock.json \n@@\n-old\n+new\n*** End Patch')"
check 2 'header with trailing space' "$protect"
patch_payload "$(printf '*** Begin Patch\r\n*** Update File: package-lock.json\r\n@@\r\n-old\r\n+new\r\n*** End Patch\r\n')"
check 2 'CRLF header' "$protect"
patch_payload "*** Begin Patch
*** Update File: package-lock.json$nbsp
@@
-old
+new
*** End Patch"
check 2 'header with trailing NBSP' "$protect"
patch_payload '*** Begin Patch
  *** Update File: package-lock.json
@@
-old
+new
*** End Patch'
check 2 'indented first header' "$protect"
patch_payload "$(printf '*** Begin Patch\n\t*** Delete File: package-lock.json\n*** End Patch')"
check 2 'tab-indented Delete' "$protect"
patch_payload "$(printf '*** Begin Patch\n*** Update File: src.txt\n*** Move to: yarn.lock  \n@@\n-old\n+new\n*** End Patch')"
check 2 'Move to with trailing spaces' "$protect"
# The BLOCKED hint, read from the case just above.
if grep -q '(e.g. package.json)' "$tmp/output"; then pass=$((pass + 1)); else
  fail=$((fail + 1)); echo 'FAIL: BLOCKED hint wording'
fi
# Header trimming stays linear on a long interior whitespace run.
if python3 - "$protect" <<'PY'
import json, subprocess, sys, time
line = '*** Add File: a' + ' ' * 100000 + 'b.txt'
payload = json.dumps({'tool_name': 'apply_patch', 'tool_input': {'command': '*** Begin Patch\n' + line + '\n+x\n*** End Patch'}})
start = time.monotonic()
try:
    rc = subprocess.run(['bash', '-c', sys.argv[1]], input=payload, text=True, capture_output=True, timeout=10).returncode
except subprocess.TimeoutExpired:
    sys.exit(1)
sys.exit(0 if rc == 0 and time.monotonic() - start < 2 else 1)
PY
then pass=$((pass + 1)); else fail=$((fail + 1)); echo 'FAIL: 100k-space header line took 2s or more'; fi
# Unreadable input is not a call the hooks can judge; they let it through.
printf 'not json' >"$tmp/payload"
check 0 'malformed payload, file-protection' "$protect"
check 0 'malformed payload, large-file-guard' "$size"
# Real patch headers, relative paths, every operation, and both move endpoints.
for operation in Add Update Delete; do
  patch_payload "*** Begin Patch
*** $operation File: package-lock.json
*** End Patch"
  check 2 "$operation lockfile" "$protect"
done
for path in node_modules/a.js vendor/a.go .git/config nested/../vendor/a.go; do
  patch_payload "*** Begin Patch
*** Add File: $path
+x
*** End Patch"
  check 2 "relative or normalized path $path" "$protect"
done
patch_payload '*** Begin Patch
*** Update File: source.txt
*** Move to: vendor/destination.txt
@@
-old
+new
*** End Patch'
check 2 'protected move destination' "$protect"
patch_payload '*** Begin Patch
*** Update File: vendor/source.txt
*** Move to: destination.txt
@@
-old
+new
*** End Patch'
check 2 'protected move source' "$protect"
patch_payload '*** Begin Patch
*** Add File: safe.txt
+*** Add File: vendor/fake-header.txt
*** Update File: other.txt
@@
-a
+b
*** End Patch'
check 0 'safe multi-file patch and header-like content' "$protect"
# Character count includes the newline added by each + line.
python3 - <<'PY' >"$tmp/payload"
import json
print(json.dumps({'tool_name':'apply_patch','tool_input':{'command':'*** Begin Patch\n*** Add File: big.txt\n+'+'x'*1048576+'\n*** End Patch'}}))
PY
check 2 'oversized native Add File' "$size"
python3 - <<'PYCASE' >"$tmp/payload"
import json
print(json.dumps({'tool_name':'apply_patch','tool_input':{'command':'*** Begin Patch\n*** Update File: big.txt\n@@\n+'+'x'*1048576+'\n*** End Patch'}}))
PYCASE
check 2 'oversized native Update File added text' "$size"
python3 - <<'PY' >"$tmp/payload"
import json
print(json.dumps({'tool_name':'apply_patch','tool_input':{'command':'*** Begin Patch\n*** Update File: big.txt\n@@\n+'+'é'*1048575+'\n*** End Patch'}}))
PY
check 0 'unicode character limit inclusive' "$size"
python3 - <<'PY' >"$tmp/payload"
import json
piece='+'+'x'*600000+'\n'
print(json.dumps({'tool_name':'apply_patch','tool_input':{'command':'*** Begin Patch\n*** Add File: one.txt\n'+piece+'*** Add File: two.txt\n'+piece+'*** End Patch'}}))
PY
check 0 'size limit per file, not whole patch' "$size"
# Avoid dependence on installed formatters and verify actual invocation order.
mkdir "$tmp/bin"
cat >"$tmp/bin/gofmt" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$2" >>"$FORMAT_LOG"
printf 'package main\n' >"$2"
STUB
chmod +x "$tmp/bin/gofmt"
export PATH="$tmp/bin:$PATH"
export FORMAT_LOG="$tmp/formatted"
export PLUGIN_ROOT="$format"
format_cmd=$(command_for "$format/hooks/codex-hooks.json" 'ogxo-format: jq not found')
printf 'package main \n' >"$tmp/first.go"
printf 'package main \n' >"$tmp/moved.go"
printf 'deleted but still present \n' >"$tmp/deleted.go"
patch_payload '*** Begin Patch
*** Add File: first.go
+package main
*** Update File: source.go
*** Move to: moved.go
@@
-a
+b
*** Delete File: deleted.go
*** End Patch'
check 0 'format all surviving destinations after native patch' "$format_cmd"
if [ "$(cat "$FORMAT_LOG")" = "first.go
moved.go" ] && [ "$(cat "$tmp/first.go")" = 'package main' ] && [ "$(cat "$tmp/moved.go")" = 'package main' ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1)); echo 'FAIL: actual formatter output/destinations'
fi
printf 'one \n' >"$tmp/one.txt"
printf 'two \n' >"$tmp/two.txt"
patch_payload '*** Begin Patch
*** Add File: one.txt
+one
*** Update File: two.txt
@@
-a
+b
*** End Patch'
check 2 'aggregate diagnostics across files' "$format_cmd"
if grep -q 'one.txt' "$tmp/output" && grep -q 'two.txt' "$tmp/output"; then
  pass=$((pass + 1))
else
  fail=$((fail + 1)); echo 'FAIL: missing per-file diagnostics'
fi
# Claude-compatible path payload still reaches the same implementation.
jq -n --arg p "$tmp/one.txt" '{tool_name:"Write",tool_input:{file_path:$p,content:"one "}}' >"$tmp/payload"
check 2 'legacy file_path payload' "$format_cmd"
printf 'not json' >"$tmp/payload"
check 0 'malformed payload, format' "$format_cmd"
# A cwd that no longer exists still lets absolute paths through.
jq -n --arg p "$tmp/one.txt" '{tool_name:"Write",cwd:"/nonexistent/ogxo-format",tool_input:{file_path:$p}}' >"$tmp/payload"
check 2 'missing cwd, absolute path still checked' "$format_cmd"
# A file name that looks like an option reaches the formatter as a path.
mkdir -p "$tmp/node_modules/.bin"
cat >"$tmp/node_modules/.bin/prettier" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$PRETTIER_LOG"
STUB
chmod +x "$tmp/node_modules/.bin/prettier"
export PRETTIER_LOG="$tmp/prettier-args"
printf 'x\n' >"$tmp/--plugin=x.js"
: >"$FORMAT_LOG"
patch_payload '*** Begin Patch
*** Add File: --plugin=x.js
+x
*** Add File: --dash.go
+package main
*** End Patch'
if command -v npx >/dev/null 2>&1; then
  printf 'x\n' >"$tmp/--dash.go"
  check 0 'option-like file names' "$format_cmd"
  if grep -qx -- './--plugin=x.js' "$PRETTIER_LOG" 2>/dev/null && ! grep -qx -- '--plugin=x.js' "$PRETTIER_LOG"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1)); echo 'FAIL: prettier got an option-like file name'; cat "$PRETTIER_LOG" 2>/dev/null
  fi
else
  echo 'SKIP: prettier option-like name (npx not installed)'
  printf 'x\n' >"$tmp/--dash.go"
  check 0 'option-like file names' "$format_cmd"
fi
if [ "$(cat "$FORMAT_LOG")" = './--dash.go' ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1)); echo 'FAIL: gofmt got an option-like file name'; cat "$FORMAT_LOG"
fi
# Codex's own parser (apply-patch/src/streaming_parser.rs, rust-v0.160.1)
# matches headers inside an Update section after trim_end only (:227-229), so
# a line starting with a space there is a context line (:318), and it accepts
# Move to only before the first hunk line and only once (:253-256).
export PLUGIN_ROOT="$guards"
patch_payload '*** Begin Patch
*** Update File: src.txt
*** Move to: vendor/dest.txt
@@
 *** Move to: safe.txt
-a
+b
*** End Patch'
check 2 'indented Move to context line keeps the real destination' "$protect"
patch_payload "$(printf '*** Begin Patch\n*** Update File: src.txt\n@@\n-a\n+b\n\t*** Update File: vendor/x.txt\n-c\n+d\n*** End Patch')"
check 2 'tab-indented header in an Update section (Codex rejects) is still checked' "$protect"
patch_payload '*** Begin Patch
*** Update File: src.txt
@@
-a
+b
*** Move to: vendor/late.txt
*** End Patch'
check 2 'Move to after a hunk line (Codex rejects) is still checked' "$protect"
patch_payload '*** Begin Patch
*** Update File: src.txt
*** Move to: vendor/first.txt
*** Move to: second.txt
@@
-a
+b
*** End Patch'
check 2 'second Move to (Codex rejects) keeps the first destination checked' "$protect"
patch_payload '*** Begin Patch
*** Add File: new.txt
+x
*** Move to: vendor/after-add.txt
*** End Patch'
check 2 'Move to after Add (Codex rejects) is still checked' "$protect"
for other in big.txt other.txt; do
  python3 - "$other" <<'PYSPLIT' >"$tmp/payload"
import json, sys
b = '+' + 'x' * 600000
patch = '*** Begin Patch\n*** Update File: big.txt\n@@\n' + b + '\n *** Update File: ' + sys.argv[1] + '\n' + b + '\n*** End Patch'
print(json.dumps({'tool_name': 'apply_patch', 'tool_input': {'command': patch}}))
PYSPLIT
  check 2 "added text split by an indented Update File: $other context line" "$size"
done
python3 - <<'PYTWO' >"$tmp/payload"
import json
b = '+' + 'x' * 600000
patch = '*** Begin Patch\n*** Update File: big.txt\n@@\n' + b + '\n*** Update File: big.txt\n@@\n' + b + '\n*** End Patch'
print(json.dumps({'tool_name': 'apply_patch', 'tool_input': {'command': patch}}))
PYTWO
check 2 'added text split across two Update sections of one path' "$size"
# Positive control: the indented header is one context line, not a record.
patch_payload '*** Begin Patch
*** Update File: a.txt
@@
-old a
+new a
 *** Update File: b.txt
@@
-old b
+new b
*** End Patch'
records=$(jq -c -f "$guards/hooks/patch-files.jq" "$tmp/payload")
if [ "$records" = '[{"path":"a.txt","kind":"update","added":12}]' ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1)); echo "FAIL: indented Update File context line made a record: $records"
fi
# The formatter targets the real Move destination, not the context line.
export PLUGIN_ROOT="$format"
printf 'package main \n' >"$tmp/real.go"
printf 'package main \n' >"$tmp/safe.go"
: >"$FORMAT_LOG"
patch_payload '*** Begin Patch
*** Update File: src.go
*** Move to: real.go
@@
 *** Move to: safe.go
-a
+b
*** End Patch'
check 0 'format after an indented Move to context line' "$format_cmd"
if [ "$(cat "$FORMAT_LOG")" = 'real.go' ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1)); echo 'FAIL: formatter did not target the real Move destination'; cat "$FORMAT_LOG"
fi
# Without jq on PATH, each command prints its notice and exits 1.
mkdir "$tmp/nojq"
for tool in bash cat dirname; do ln -s "$(command -v "$tool")" "$tmp/nojq/$tool"; done
patch_payload '*** Begin Patch
*** Add File: package-lock.json
+{}
*** End Patch'
for hook in "ogxo-guards/file-protection|$guards|$protect" "ogxo-guards/large-file-guard|$guards|$size" "ogxo-format|$format|$format_cmd"; do
  label=${hook%%|*}; rest=${hook#*|}; plugin_root=${rest%%|*}; cmd=${rest#*|}
  PATH="$tmp/nojq" PLUGIN_ROOT="$plugin_root" "$tmp/nojq/bash" -c "$cmd" <"$tmp/payload" >"$tmp/stdout" 2>"$tmp/stderr"
  got=$?
  if [ "$got" -eq 1 ] && grep -q "$label: jq not found" "$tmp/stderr" && [ ! -s "$tmp/stdout" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1)); echo "FAIL: $label without jq (expected 1 and a notice, got $got)"; cat "$tmp/stderr"
  fi
done
echo "Codex hook tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

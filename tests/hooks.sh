#!/usr/bin/env bash
# Regression tests for the ogxo-guards and ogxo-format hook commands.
# Each case pipes a crafted tool-call payload into the hook command taken
# straight from hooks.json and checks its exit code (2 = blocked/reported).
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
guards="$root/plugins/ogxo-guards/hooks/hooks.json"
format="$root/plugins/ogxo-format/hooks/hooks.json"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# Hook commands that run a bundled script find it through this variable.
export CLAUDE_PLUGIN_ROOT="$root/plugins/ogxo-guards"

pass=0
fail=0

# hook_cmd <hooks.json> <label>: the command whose jq-missing notice names <label>.
hook_cmd() {
  local cmd
  cmd=$(jq -r --arg l "$2" '[.hooks[][].hooks[] | select(.command | contains($l))][0].command // empty' "$1")
  [ -n "$cmd" ] || { echo "no hook labelled $2 in $1" >&2; exit 1; }
  printf '%s' "$cmd"
}

# check <expected exit> <description> <hook command> <payload file>
check() {
  local got
  bash -c "$3" <"$4" >/dev/null 2>&1
  got=$?
  if [ "$got" -eq "$1" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: $2 (expected exit $1, got $got)"
  fi
}

# bash_case <expected exit> <git command line>
bash_case() {
  jq -n --arg c "$2" '{tool_input: {command: $c}}' >"$tmp/payload"
  check "$1" "env-file-guard: $2" "$env_guard" "$tmp/payload"
}

# path_case <expected exit> <hook command> <label> <file path>
path_case() {
  jq -n --arg f "$4" '{tool_input: {file_path: $f}}' >"$tmp/payload"
  check "$1" "$3: $4" "$2" "$tmp/payload"
}

env_guard=$(hook_cmd "$guards" "ogxo-guards/env-file-guard")
bash_case 2 'git add .env'
bash_case 2 'git add ".env"'
bash_case 2 "git add '.env'"
bash_case 2 'git add .env&&ls'
bash_case 2 'git add .env;echo done'
bash_case 2 '(git add .env)'
bash_case 2 'echo x && git add .env'
bash_case 2 'git -C sub add .env'
bash_case 2 'git stage .env'
bash_case 2 'git add src/.env.local'
bash_case 2 'git add config/credentials.json'
bash_case 2 'git add key.pem'
bash_case 0 'git add README.md'
bash_case 0 'git add docs/env.md environment.ts'
bash_case 0 'git commit -m "add .env docs"'
bash_case 0 'git addx .env'
bash_case 2 'git add config/.env.local'
bash_case 2 'git add id_rsa'
bash_case 2 'git add certs/server.key'
bash_case 0 'git add id_rsa.pub'
bash_case 0 'git add .env.example'
# The rest of the command is not what gets staged.
bash_case 0 'cp .env ../wt/ && git add src/a.rs'
bash_case 0 'set -a && . ./.env && git add src/a.rs'
bash_case 0 'git status --porcelain | grep -v ".envrc" ; git add src/x.ts'
bash_case 0 'FOO=1 git add README.md # .env'

# repo_case <expected exit> <description> <git command line>: runs in $repo.
repo_case() {
  jq -n --arg c "$3" --arg d "$repo" '{cwd: $d, tool_input: {command: $c}}' >"$tmp/payload"
  check "$1" "env-file-guard: $2" "$env_guard" "$tmp/payload"
}
repo="$tmp/repo"
git init -q "$repo"
mkdir -p "$repo/src" "$repo/.claude"
echo x >"$repo/src/a.rs"
echo SECRET=1 >"$repo/.env"
repo_case 2 'add -A with an untracked .env' 'git add -A'
repo_case 2 'add . with an untracked .env' 'git add .'
repo_case 0 'add of a directory without secrets' 'git add src'
repo_case 0 'add -u ignores untracked .env' 'git add -u'
repo_case 2 'git -C <repo> add -A' "git -C $repo add -A"
echo .env >"$repo/.gitignore"
repo_case 0 'add -A with .env ignored' 'git add -A'
echo npmrc >"$repo/.npmrc"
repo_case 0 'add -A with .npmrc, no repo list' 'git add -A'
printf '# repo additions\n(^|/)\\.npmrc$\n' >"$repo/.claude/ogxo-guards-sensitive"
repo_case 2 'add -A with .npmrc in the repo list' 'git add -A'
repo_case 2 'add .npmrc named in the repo list' 'git add .npmrc'

protect=$(hook_cmd "$guards" "ogxo-guards/file-protection")
for f in /r/package-lock.json package-lock.json /r/web/pnpm-lock.yaml /r/yarn.lock \
  /r/Cargo.lock /r/go.sum /r/uv.lock /r/node_modules/x/index.js /r/vendor/a/b.go /r/.git/config; do
  path_case 2 "$protect" file-protection "$f"
done
path_case 0 "$protect" file-protection /r/src/index.ts
path_case 0 "$protect" file-protection /r/package.json

large=$(hook_cmd "$guards" "ogxo-guards/large-file-guard")
python3 -c 'import json; print(json.dumps({"tool_input": {"content": "x" * 1048577}}))' >"$tmp/big"
check 2 "large-file-guard: 1,048,577 characters" "$large" "$tmp/big"
python3 -c 'import json; print(json.dumps({"tool_input": {"content": "x" * 1048576}}))' >"$tmp/big"
check 0 "large-file-guard: 1,048,576 characters" "$large" "$tmp/big"
echo '{"tool_input": {}}' >"$tmp/payload"
check 0 "large-file-guard: no content" "$large" "$tmp/payload"

# One hook formats, then checks, in that order; the checks must never race the formatter.
format_hook=$(hook_cmd "$format" "ogxo-format: jq not found")
trailing=$format_hook
printf 'x = 1 \n' >"$tmp/dirty.py"
printf 'x = 1\n' >"$tmp/clean.py"
printf 'line with hard break  \nnext\n' >"$tmp/doc.md"
path_case 2 "$trailing" trailing-whitespace "$tmp/dirty.py"
path_case 0 "$trailing" trailing-whitespace "$tmp/clean.py"
path_case 0 "$trailing" trailing-whitespace "$tmp/doc.md"

if python3 -c 'import yaml' 2>/dev/null; then
  yaml_check=$format_hook
  printf 'a: [1, 2\n' >"$tmp/bad.yaml"
  printf 'a: 1\n---\nb: 2\n' >"$tmp/multi.yaml"
  printf 'Value: !Ref Bucket\n' >"$tmp/tag.yaml"
  path_case 2 "$yaml_check" yaml-validate "$tmp/bad.yaml"
  path_case 0 "$yaml_check" yaml-validate "$tmp/multi.yaml"
  path_case 0 "$yaml_check" yaml-validate "$tmp/tag.yaml"
else
  echo "SKIP: yaml-validate cases (PyYAML not installed)"
fi

echo "hook tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

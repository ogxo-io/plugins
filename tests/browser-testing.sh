#!/usr/bin/env bash
# Tests for how plugins/ogxo-debug/skills/browser-testing/scripts/run-playwright.js
# finds Playwright: the plugin data dir, then the project's own copy, then a
# one-time install. Fake `playwright` modules and stubs of `npm` and `npx` that
# record their calls stand in for the real packages, so nothing is downloaded.
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
runner="$root/plugins/ogxo-debug/skills/browser-testing/scripts/run-playwright.js"
command -v node >/dev/null 2>&1 || { echo "SKIP: browser-testing tests (node not installed)"; exit 0; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
expect() {
  local desc=$1
  shift
  if "$@" >/dev/null 2>&1; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $desc"; fi
}

# fake <dir> <package name> <marker> <exe path>: a module whose chromium
# executable is <exe path>.
fake() {
  mkdir -p "$1/node_modules/$2"
  printf '{"name":"%s","main":"index.js"}\n' "$2" >"$1/node_modules/$2/package.json"
  printf 'module.exports = { marker: "%s", chromium: { executablePath: () => "%s" } };\n' "$3" "$4" >"$1/node_modules/$2/index.js"
}

stubs="$tmp/stubs"
mkdir -p "$stubs"
# npm ci: installs a fake playwright into the cwd (the data dir) unless NPM_FAIL is set.
cat >"$stubs/npm" <<'STUB'
#!/usr/bin/env bash
echo "npm $*" >>"$CALLS"
[ -z "${NPM_FAIL:-}" ] || exit 1
mkdir -p node_modules/playwright
printf '{"name":"playwright","main":"index.js"}\n' >node_modules/playwright/package.json
printf 'module.exports = { marker: "home", chromium: { executablePath: () => "%s" } };\n' "$HOME_EXE" >node_modules/playwright/index.js
STUB
# npx playwright install chromium: creates the browser executable.
cat >"$stubs/npx" <<'STUB'
#!/usr/bin/env bash
echo "npx $*" >>"$CALLS"
: >"$HOME_EXE"
STUB
chmod +x "$stubs"/*

code_js='const pw = require("playwright"); console.log("RAN " + pw.marker);'
# run <cwd> [VAR=value ...]: run the runner with inline code; sets $out, $code.
run() {
  local cwd=$1
  shift
  : >"$tmp/calls"
  out=$(cd "$cwd" && env PATH="$stubs:$PATH" CALLS="$tmp/calls" HOME_EXE="$tmp/home-chromium" \
    BROWSER_TESTING_HOME="$tmp/data" "$@" node "$runner" "$code_js" 2>&1)
  code=$?
}
calls() { cat "$tmp/calls"; }

proj="$tmp/proj"
mkdir -p "$proj"
: >"$tmp/proj-chromium"
fake "$proj" playwright project "$tmp/proj-chromium"

run "$proj"
expect "project: exit 0" [ "$code" -eq 0 ]
expect "project: uses the project's playwright" grep -q 'RAN project' <<<"$out"
expect "project: says so" grep -qF "Using the project's Playwright (playwright)" <<<"$out"
expect "project: installs nothing" [ ! -s "$tmp/calls" ]

pnpm="$tmp/pnpm"
mkdir -p "$pnpm"
fake "$pnpm" @playwright/test pwtest "$tmp/proj-chromium"
run "$pnpm"
expect "@playwright/test only: used for require('playwright')" grep -q 'RAN pwtest' <<<"$out"

nob="$tmp/nobrowser"
mkdir -p "$nob"
fake "$nob" playwright project "$tmp/missing-chromium"
run "$nob" BROWSER_TESTING_NO_INSTALL=1
expect "no browser + NO_INSTALL: exit 1" [ "$code" -ne 0 ]
expect "no browser + NO_INSTALL: installs nothing" [ ! -s "$tmp/calls" ]
expect "no browser + NO_INSTALL: says why" grep -q 'BROWSER_TESTING_NO_INSTALL=1 is set' <<<"$out"

run "$tmp" NPM_FAIL=1
expect "install fails: exit 1" [ "$code" -ne 0 ]
expect "install fails: points at the output" grep -q 'one-time install failed' <<<"$out"
expect "install fails: lock removed" [ ! -e "$tmp/data/.installing" ]

run "$tmp"
expect "install: exit 0" [ "$code" -eq 0 ]
expect "install: npm ci, then the chromium download" [ "$(calls | paste -sd, -)" = "npm ci --no-audit --no-fund,npx playwright install chromium" ]
expect "install: pinned package files copied" cmp -s "$root/plugins/ogxo-debug/skills/browser-testing/package-lock.json" "$tmp/data/package-lock.json"
expect "install: runs with the installed copy" grep -q 'RAN home' <<<"$out"
expect "install: says what it downloads" grep -q 'one time, downloads a browser build' <<<"$out"

run "$proj"
expect "installed: the data dir copy wins over the project's" grep -q 'RAN home' <<<"$out"
expect "installed: nothing installed again" [ ! -s "$tmp/calls" ]

rm -f "$tmp/home-chromium"
run "$tmp"
expect "browser missing: only the chromium download runs" [ "$(calls)" = "npx playwright install chromium" ]
expect "browser missing: then runs" grep -q 'RAN home' <<<"$out"

rm -f "$tmp/home-chromium"
mkdir -p "$tmp/data/.installing"
touch -t 202001010000 "$tmp/data/.installing"
run "$tmp"
expect "stale lock: taken over and the install runs" grep -q 'RAN home' <<<"$out"
expect "stale lock: removed afterwards" [ ! -e "$tmp/data/.installing" ]

ro="$tmp/readonly"
mkdir -p "$ro"
chmod 555 "$ro"
: >"$tmp/calls"
(cd "$tmp" && env PATH="$stubs:$PATH" CALLS="$tmp/calls" HOME_EXE="$tmp/ro-chromium" BROWSER_TESTING_HOME="$ro" \
  node "$runner" "$code_js" >"$tmp/ro-out" 2>&1) &
pid=$!
for _ in $(seq 1 100); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
if kill -0 "$pid" 2>/dev/null; then kill "$pid"; hung=1; else hung=0; fi
wait "$pid"
code=$?
chmod 755 "$ro"
expect "unwritable data dir: does not hang" [ "$hung" -eq 0 ]
expect "unwritable data dir: exit 1" [ "$code" -ne 0 ]
expect "unwritable data dir: says the install failed" grep -q 'one-time install failed' "$tmp/ro-out"

# Data directory resolution: BROWSER_TESTING_HOME, then PLUGIN_DATA, then the cache;
# CLAUDE_PLUGIN_DATA (possibly another plugin's) and an unfilled "/browser-testing" are ignored.
homeprobe='console.log(1)'
resolve() { # resolve [VAR=value ...]: the data dir the runner chose, in $out
  out=$(cd "$tmp" && env -u BROWSER_TESTING_HOME -u PLUGIN_DATA -u CLAUDE_PLUGIN_DATA -u XDG_CACHE_HOME \
    HOME="$tmp/fakehome" BROWSER_TESTING_NO_INSTALL=1 PATH="$stubs:$PATH" CALLS="$tmp/calls" "$@" \
    node "$runner" "$homeprobe" 2>&1)
  out=$(printf '%s\n' "$out" | sed -n 's/.*not in \(.*\) nor in the project.*/\1/p')
}
real() { printf "%s\n" "$1"; }
resolve BROWSER_TESTING_HOME="$tmp/explicit"
expect "home: BROWSER_TESTING_HOME wins" [ "$out" = "$(real "$tmp/explicit")" ]
resolve BROWSER_TESTING_HOME=/browser-testing PLUGIN_DATA="$tmp/pd"
expect "home: '/browser-testing' is ignored, PLUGIN_DATA used" [ "$out" = "$(real "$tmp/pd/browser-testing")" ]
resolve PLUGIN_DATA="$tmp/pd"
expect "home: PLUGIN_DATA/browser-testing" [ "$out" = "$(real "$tmp/pd/browser-testing")" ]
resolve CLAUDE_PLUGIN_DATA="$tmp/leaked"
expect "home: CLAUDE_PLUGIN_DATA is never read" [ "$out" = "$(real "$tmp/fakehome/.cache/ogxo-debug/browser-testing")" ]
expect "home: leaked CLAUDE_PLUGIN_DATA dir not created" [ ! -e "$tmp/leaked" ]
resolve BROWSER_TESTING_HOME=/browser-testing XDG_CACHE_HOME="$tmp/xdg"
expect "home: '/browser-testing' falls back to XDG_CACHE_HOME" [ "$out" = "$(real "$tmp/xdg/ogxo-debug/browser-testing")" ]

echo "browser-testing tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

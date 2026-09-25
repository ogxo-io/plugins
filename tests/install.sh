#!/usr/bin/env bash
# Tests for install.sh against a stub `claude` that records every call and
# serves a fixed marketplace. Runs the script under each bash on the machine,
# including macOS's /bin/bash 3.2, since `curl ... | bash` picks that one there.
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
script="$root/install.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0

# The stub reads its state from $STUB_DIR: has_market (marketplace added),
# installed (one plugin name per line), and fail_on (a plugin whose install fails).
mkdir -p "$tmp/bin"
cat >"$tmp/bin/claude" <<'STUB'
#!/usr/bin/env bash
echo "claude $*" >>"$STUB_DIR/calls"
case "$*" in
  "plugin marketplace list --json")
    if [ -f "$STUB_DIR/has_market" ]; then
      echo '[{"name":"other"},{"name":"ogxo"}]'
    else
      echo '[{"name":"other"}]'
    fi ;;
  "plugin marketplace add "*) touch "$STUB_DIR/has_market" ;;
  "plugin marketplace update ogxo") ;;
  "plugin list --available --json")
    installed=$(sed 's/.*/{"id":"&@ogxo"}/' "$STUB_DIR/installed" 2>/dev/null | paste -sd, -)
    available=""
    for p in ogxo thryx ogxo-git ogxo-review ogxo-format ogxo-statusline; do
      grep -qxF "$p" "$STUB_DIR/installed" 2>/dev/null && continue
      available+="${available:+,}{\"name\":\"$p\",\"marketplaceName\":\"ogxo\"}"
    done
    available+="${available:+,}{\"name\":\"ogxo-git\",\"marketplaceName\":\"other\"}"
    installed+="${installed:+,}{\"id\":\"x@other\"}"
    echo "{\"installed\":[${installed}],\"available\":[${available}]}" ;;
  "plugin install "* | "plugin update "*)
    p=${3%@*}
    [ "$p" = "$(cat "$STUB_DIR/fail_on" 2>/dev/null)" ] && exit 1
    echo "$p" >>"$STUB_DIR/installed" ;;
  *) echo "unexpected: $*" >&2; exit 9 ;;
esac
STUB
chmod +x "$tmp/bin/claude"

# run_case <bash> <description> <setup> <expected exit> <args...>
# setup: "" (fresh), "market" (marketplace added), or "market+git" (and ogxo-git installed).
run_case() {
  local sh=$1 desc=$2 setup=$3 want=$4
  shift 4
  export STUB_DIR="$tmp/state"
  rm -rf "$STUB_DIR"
  mkdir -p "$STUB_DIR"
  case "$setup" in
    market) touch "$STUB_DIR/has_market" ;;
    market+git) touch "$STUB_DIR/has_market"; echo ogxo-git >"$STUB_DIR/installed" ;;
  esac
  out=$(PATH="$tmp/bin:$PATH" "$sh" "$script" "$@" 2>&1)
  code=$?
  calls=$(cat "$STUB_DIR/calls" 2>/dev/null)
  if [ "$code" -ne "$want" ]; then
    fail=$((fail + 1))
    printf 'FAIL [%s] %s: exit %s, wanted %s\n%s\n' "$sh" "$desc" "$code" "$want" "$out"
    return 1
  fi
  return 0
}

# expect_in / expect_not_in <text> <haystack>: record a pass or fail for the current case.
expect_in() {
  if [[ "$2" == *"$1"* ]]; then pass=$((pass + 1)); else
    fail=$((fail + 1)); printf 'FAIL [%s] %s: missing %q in:\n%s\n' "$sh_name" "$case_name" "$1" "$2"; fi
}
expect_not_in() {
  if [[ "$2" != *"$1"* ]]; then pass=$((pass + 1)); else
    fail=$((fail + 1)); printf 'FAIL [%s] %s: unexpected %q in:\n%s\n' "$sh_name" "$case_name" "$1" "$2"; fi
}

shells=(bash)
[ -x /bin/bash ] && shells+=(/bin/bash)

for sh_name in "${shells[@]}"; do
  case_name="fresh --all installs the bundle"
  if run_case "$sh_name" "$case_name" "" 0 --all; then
    expect_in "claude plugin marketplace add ogxo-io/plugins" "$calls"
    expect_in "claude plugin install ogxo@ogxo" "$calls"
    expect_not_in "thryx@ogxo" "$calls"
    expect_not_in "ogxo-format@ogxo" "$calls"
    expect_not_in "ogxo-git@ogxo" "$calls"
    expect_in "Not in the bundle: ogxo-format" "$out"
    expect_in "Not in the bundle: thryx" "$out"
    expect_in "/ogxo-statusline:setup" "$out"
    expect_not_in "THRYX_WORKSPACE" "$out"
  fi

  case_name="--all --include-format"
  if run_case "$sh_name" "$case_name" market 0 --all --include-format; then
    expect_in "claude plugin marketplace update ogxo" "$calls"
    expect_not_in "marketplace add" "$calls"
    expect_in "claude plugin install ogxo@ogxo" "$calls"
    expect_in "claude plugin install ogxo-format@ogxo" "$calls"
    expect_not_in "Not in the bundle: ogxo-format" "$out"
    expect_in "Not in the bundle: thryx" "$out"
  fi

  case_name="--all --include-thryx"
  if run_case "$sh_name" "$case_name" market 0 --all --include-thryx; then
    expect_in "claude plugin install thryx@ogxo" "$calls"
    expect_in "THRYX_WORKSPACE" "$out"
    expect_not_in "ogxo-format@ogxo" "$calls"
  fi

  case_name="--include-format without --all is refused"
  run_case "$sh_name" "$case_name" market 1 --include-format ogxo-git && pass=$((pass + 1))

  case_name="named plugins, one already installed"
  if run_case "$sh_name" "$case_name" market+git 0 ogxo-git ogxo-review@ogxo; then
    expect_in "claude plugin update ogxo-git@ogxo" "$calls"
    expect_in "claude plugin install ogxo-review@ogxo" "$calls"
    expect_not_in "thryx" "$calls"
  fi

  case_name="--list marks installed and opt-in"
  if run_case "$sh_name" "$case_name" market+git 0 --list; then
    expect_in "ogxo-git (installed)" "$out"
    expect_in "ogxo-format (opt-in: not in the bundle)" "$out"
    expect_in "thryx (opt-in: not in the bundle)" "$out"
    expect_in "ogxo (bundle:" "$out"
    expect_not_in "plugin install" "$calls"
  fi

  case_name="no arguments lists and installs nothing"
  if run_case "$sh_name" "$case_name" market 0; then
    expect_in "Usage:" "$out"
    expect_in "ogxo-review" "$out"
    expect_not_in "plugin install" "$calls"
  fi

  case_name="unknown plugin is refused before any install"
  if run_case "$sh_name" "$case_name" market 1 ogxo-git nope; then
    expect_in "no plugin named 'nope'" "$out"
    expect_not_in "plugin install" "$calls"
  fi

  case_name="a plugin from another marketplace is not ours"
  if run_case "$sh_name" "$case_name" market 0 ogxo-git ogxo-review; then
    expect_not_in "@other" "$calls"
  fi

  case_name="names and --all together are refused"
  run_case "$sh_name" "$case_name" market 1 --all ogxo-git && pass=$((pass + 1))

  case_name="unknown option is refused"
  run_case "$sh_name" "$case_name" market 1 --bogus && pass=$((pass + 1))

  case_name="a failed install is reported and the rest still run"
  export STUB_DIR="$tmp/state"
  rm -rf "$STUB_DIR"; mkdir -p "$STUB_DIR"; touch "$STUB_DIR/has_market"; echo ogxo-review >"$STUB_DIR/fail_on"
  out=$(PATH="$tmp/bin:$PATH" "$sh_name" "$script" ogxo-review ogxo-git 2>&1)
  code=$?
  calls=$(cat "$STUB_DIR/calls")
  if [ "$code" -eq 1 ]; then pass=$((pass + 1)); else
    fail=$((fail + 1)); printf 'FAIL [%s] %s: exit %s, wanted 1\n%s\n' "$sh_name" "$case_name" "$code" "$out"; fi
  expect_in "failed: ogxo-review" "$out"
  expect_in "claude plugin install ogxo-git@ogxo" "$calls"
done

# Without claude on PATH the script stops with a clear message.
out=$(PATH=/usr/bin:/bin bash "$script" --all 2>&1)
if [ $? -eq 1 ] && [[ "$out" == *"claude (Claude Code) is not on PATH"* ]]; then pass=$((pass + 1)); else
  fail=$((fail + 1)); printf 'FAIL: missing claude is reported\n%s\n' "$out"; fi

echo "install tests: $pass passed, $fail failed (shells: ${shells[*]})"
[ "$fail" -eq 0 ]

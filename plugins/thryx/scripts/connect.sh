#!/usr/bin/env bash
# Connect ThryX to Claude Code or Codex as one MCP server.
#   connect.sh [--client claude|codex] [--set-token] [--token-var NAME] [--replace] [--clean-old]
# Adds an HTTP server named thryx for https://app.thryx.io/api/v1/mcp, which
# reaches every workspace the token does; the agent names the workspace on
# each call. Claude Code gets ?tools=all (every tool listed; Claude Code
# defers tool schemas itself), Codex the default core list. A header helper
# builds the Authorization header each time the server connects, so the
# token is never written to the client's config and never printed here.
#
# Where the helper reads the token from:
# - macOS (the `security` tool exists), unless --token-var is given: the login
#   Keychain, item "thryx-mcp", account "shared". When the item is missing,
#   or with --set-token, a dialog with hidden input asks for the token and
#   stores it.
# - Otherwise: an environment variable, THRYX_TOKEN or the one --token-var
#   names, which must be set in the environment the client started with.
#
# Codex uses http_headers_helper for the Keychain (requires Python 3), or
# --bearer-token-env-var for environment mode, without reading the token.
#
# In Claude mode, --replace removes an existing server first (for example
# one added with the token in plaintext). Codex mode updates it with mcp add.
#
# Older versions added one server per workspace, thryx-<workspace>. Once
# thryx is configured, the script lists the entries named thryx-<workspace>
# whose URL is https://app.thryx.io/api/v1/mcp/<workspace>; --clean-old
# removes those (in Claude Code, at user scope only). thryx itself never
# matches.
set -uo pipefail

usage() { echo "usage: connect [--client claude|codex] [--set-token] [--token-var NAME] [--replace] [--clean-old]" >&2; exit 2; }

client=claude
var=""
set_token=false
replace=false
clean_old=false
while [ $# -gt 0 ]; do
  case $1 in
    --client) [ $# -ge 2 ] || usage; client=$2; shift 2 ;;
    --token-var) [ $# -ge 2 ] || usage; var=$2; shift 2 ;;
    --set-token) set_token=true; shift ;;
    --replace) replace=true; shift ;;
    --clean-old) clean_old=true; shift ;;
    -*) usage ;;
    *) echo "thryx: connect takes no workspace; one server, thryx, reaches every workspace your token does" >&2; usage ;;
  esac
done
[ -z "$var" ] || [[ "$var" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || { echo "thryx: '$var' is not an environment variable name" >&2; exit 2; }

case $client in
  claude|codex) ;;
  *) echo "thryx: --client must be claude or codex" >&2; exit 2 ;;
esac

name=thryx
if [ "$client" = claude ]; then
  url="https://app.thryx.io/api/v1/mcp?tools=all"
  lists="every ThryX tool (?tools=all)"
else
  url="https://app.thryx.io/api/v1/mcp"
  lists="a core of twenty tools; the agent finds the rest with discover_tools"
fi
mint="Mint it under Account settings -> Your agent -> + New token, choosing 'Any workspace I belong to'; a token for one workspace reaches only that workspace."

# Old per-workspace entries, one name per line: named thryx-<workspace> and
# pointing at the per-workspace endpoint, so a thryx-staging or thryx-local
# server someone added by hand is left alone. Fails when the client's list
# can't be read.
old_re='^thryx-[A-Za-z0-9][A-Za-z0-9_-]*$'
old_url_re='^https://app\.thryx\.io/api/v1/mcp/[A-Za-z0-9_-]+$'
old_entries() {
  local list
  if [ "$client" = claude ]; then
    list=$(claude mcp list 2>/dev/null) || return 1
    printf '%s\n' "$list" | sed -nE 's#^(thryx-[A-Za-z0-9][A-Za-z0-9_-]*): https://app\.thryx\.io/api/v1/mcp/[A-Za-z0-9_-]+ .*#\1#p'
  else
    command -v jq >/dev/null 2>&1 || return 1
    list=$(codex mcp list --json 2>/dev/null) || return 1
    printf '%s' "$list" | jq -r --arg re "$old_re" --arg url "$old_url_re" \
      '.[]? | select((.name // "" | test($re)) and (.transport.url // "" | test($url))) | .name'
  fi
}

# Report the old entries, or remove them with --clean-old. Called once
# thryx is configured, so removing them never leaves no ThryX server.
finish() {
  local old n count failed=0
  if ! old=$(old_entries); then
    echo "Check '$client mcp list' for old thryx-<workspace> entries; the thryx entry replaces them."
    return 0
  fi
  [ -n "$old" ] || return 0
  count=$(printf '%s\n' "$old" | grep -c .)
  if ! $clean_old; then
    echo "Found $count per-workspace entries ($(printf '%s\n' "$old" | paste -sd, - | sed 's/,/, /g')). The thryx entry reaches the same workspaces only if its token was minted for 'Any workspace I belong to': after restarting, check with list_workspaces, then remove them with --clean-old."
    return 0
  fi
  while IFS= read -r n; do
    [[ "$n" =~ $old_re ]] || continue
    if [ "$client" = claude ]; then
      claude mcp remove "$n" --scope user >/dev/null 2>&1
    else
      codex mcp remove "$n" >/dev/null 2>&1
    fi
    if [ $? -eq 0 ]; then
      echo "Removed the old entry $n."
    else
      echo "Could not remove $n; remove it by hand (claude mcp remove $n --scope <scope>, or codex mcp remove $n)." >&2
      failed=$((failed + 1))
    fi
  done < <(printf '%s\n' "$old")
  [ "$failed" -eq 0 ]
}

# Keep the environment option for Codex; default to Keychain where available.
if [ "$client" = codex ] && { [ -n "$var" ] || ! command -v security >/dev/null 2>&1; }; then
  if $set_token; then
    echo "thryx: --set-token requires Keychain mode; use --token-var NAME for an environment token" >&2
    exit 2
  fi
  command -v codex >/dev/null 2>&1 || { echo "thryx: the codex command was not found" >&2; exit 1; }
  var=${var:-THRYX_TOKEN}
  if codex mcp get "$name" >/dev/null 2>&1 && ! $replace; then
    echo "$name is already configured in Codex; use --replace to change its URL or token variable."
    finish
    exit
  fi
  # add updates an existing entry; do not remove it before a possibly failing add.
  codex mcp add "$name" --url "$url" --bearer-token-env-var "$var" >/dev/null \
    || { echo "thryx: codex mcp add failed for $name" >&2; exit 1; }
  echo "Configured $name ($url) in Codex; its token comes from \$$var. It lists $lists."
  echo "Set $var outside the chat before starting Codex. $mint"
  echo "Start a new Codex session; /mcp shows whether the server connected."
  echo "Add 'ThryX workspace: <slug>' to a repository's AGENTS.md if it belongs to one workspace; the agent passes that slug as workspace on each call."
  finish
  exit
fi

if [ "$client" = codex ]; then
  command -v codex >/dev/null 2>&1 || { echo "thryx: the codex command was not found" >&2; exit 1; }
  command -v python3 >/dev/null 2>&1 || { echo "thryx: Python 3 is required for Codex Keychain authentication" >&2; exit 1; }
  if codex mcp get "$name" >/dev/null 2>&1 && ! $replace && ! $set_token; then
    echo "$name is already configured in Codex; use --replace to change its authentication or URL."
    finish
    exit
  fi
else
  command -v claude >/dev/null 2>&1 || { echo "thryx: the claude command was not found" >&2; exit 1; }
  command -v jq >/dev/null 2>&1 || { echo "thryx: jq is required" >&2; exit 1; }
fi

service=thryx-mcp
account=shared

if [ -z "$var" ] && command -v security >/dev/null 2>&1; then
  mode="keychain"
else
  mode="env"
  var=${var:-THRYX_TOKEN}
fi

if [ "$mode" = keychain ]; then
  if $set_token || ! security find-generic-password -s "$service" -a "$account" >/dev/null 2>&1; then
    command -v osascript >/dev/null 2>&1 || { echo "thryx: osascript is needed to ask for the token; use --token-var instead" >&2; exit 1; }
    # The dialog runs outside the conversation: the token goes from the
    # dialog to the Keychain and is never printed.
    token=$(osascript \
      -e 'text returned of (display dialog "Paste a token for your ThryX workspaces. Mint one in the ThryX web app under Account settings > Your agent > + New token, choosing \"Any workspace I belong to\". It is stored in your login Keychain as thryx-mcp." default answer "" with hidden answer with title "ThryX" buttons {"Cancel", "Save"} default button "Save")' \
      2>/dev/null) || { echo "No token entered; nothing changed."; exit 1; }
    [ -n "$token" ] || { echo "No token entered; nothing changed."; exit 1; }
    security add-generic-password -U -s "$service" -a "$account" -l "ThryX MCP token ($account)" -w "$token" >/dev/null 2>&1 \
      || { echo "thryx: could not store the token in the Keychain" >&2; exit 1; }
    unset token
    echo "Stored the token in your login Keychain (thryx-mcp, $account)."
  fi
  helper="printf '{\"Authorization\": \"Bearer %s\"}' \"\$(security find-generic-password -s $service -a $account -w)\""
  source_desc="your login Keychain (thryx-mcp, $account)"
else
  if [ -z "${!var:-}" ]; then
    echo "\$$var is not set in the environment Claude Code started with."
    echo "$mint"
    echo "Then add this to your shell profile (for example ~/.zshrc) and restart Claude Code:"
    echo ""
    echo "  export $var='<your token>'"
    echo ""
    echo "Then run this again. Don't paste the token into the chat."
    exit 1
  fi
  helper="printf '{\"Authorization\": \"Bearer %s\"}' \"\$$var\""
  source_desc="\$$var"
fi

if [ "$client" = codex ]; then
  if codex mcp get "$name" >/dev/null 2>&1 && ! $replace; then
    echo "$name is already configured; its configuration was kept. The Keychain token was updated."
    echo "Start a new Codex session to use the new token; use --replace to switch an existing environment or OAuth configuration to Keychain authentication."
    finish
    exit
  fi
  script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  python3 "$script_dir/codex-keychain.py" "$name" "$url" "$(command -v security)" "$account" || exit 1
  echo "Configured $name ($url) in Codex; its token comes from $source_desc. It lists $lists."
  echo "Start a new Codex session; /mcp shows whether the server connected."
  echo "Saved OAuth credentials take precedence over the helper; if previously logged in, run 'codex mcp logout $name'."
  echo "Add 'ThryX workspace: <slug>' to a repository's AGENTS.md if it belongs to one workspace; the agent passes that slug as workspace on each call."
  finish
  exit
fi

if claude mcp get "$name" >/dev/null 2>&1; then
  if ! $replace; then
    if [ "$mode" = keychain ] && $set_token; then
      echo "$name is already connected and now uses the new token; reconnect it from /mcp."
    else
      echo "$name is already connected. To replace it with one whose token comes from"
      echo "$source_desc (for example if it was added with the token in plaintext),"
      echo "run this again with --replace."
    fi
    finish
    exit
  fi
  claude mcp remove "$name" >/dev/null || { echo "thryx: could not remove the existing $name; remove it with 'claude mcp remove $name --scope <scope>'" >&2; exit 1; }
  echo "Removed the existing $name."
fi

json=$(jq -nc --arg url "$url" --arg helper "$helper" '{type: "http", url: $url, headersHelper: $helper}') || exit 1
claude mcp add-json --scope user "$name" "$json" >/dev/null || { echo "thryx: claude mcp add-json failed for $name" >&2; exit 1; }

echo "Connected $name ($url) at user scope; its token comes from $source_desc. It lists $lists."
echo "Restart Claude Code to load its tools; /mcp then shows whether it connected."
echo "Add 'ThryX workspace: <slug>' to a repository's CLAUDE.md if it belongs to one workspace; the agent passes that slug as workspace on each call."
finish

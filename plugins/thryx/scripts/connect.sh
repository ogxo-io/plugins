#!/usr/bin/env bash
# Connect a ThryX workspace to Claude Code or Codex as its own MCP server.
#   connect.sh <workspace> [--client claude|codex] [--own-token] [--set-token] [--token-var NAME] [--replace]
# In Claude mode, adds a user-scope HTTP server named thryx-<workspace> for
# https://app.thryx.io/api/v1/mcp/<workspace>. Its headersHelper builds the
# Authorization header each time the server connects, so the token is never
# written to Claude Code's config and never printed here.
#
# Where the helper reads the token from:
# - macOS (the `security` tool exists), unless --token-var is given: the login
#   Keychain, item "thryx-mcp". One token is shared by every workspace
#   (account "shared"); --own-token gives this workspace its own (account
#   <workspace>). When the item is missing, or with --set-token, a dialog
#   with hidden input asks for the token and stores it.
# - Otherwise: an environment variable, THRYX_TOKEN or the one --token-var
#   names, which must be set in the environment Claude Code started with.
#
# Codex (--client codex) uses --bearer-token-env-var without reading the token
# and does not use the Keychain or require jq.
#
# In Claude mode, --replace removes an existing server first (for example
# one added with the token in plaintext). Codex mode updates it with mcp add.
set -uo pipefail

usage() { echo "usage: connect <workspace> [--client claude|codex] [--own-token] [--set-token] [--token-var NAME] [--replace]" >&2; exit 2; }

client=claude
ws=""
var=""
own=false
set_token=false
replace=false
while [ $# -gt 0 ]; do
  case $1 in
    --client) [ $# -ge 2 ] || usage; client=$2; shift 2 ;;
    --token-var) [ $# -ge 2 ] || usage; var=$2; shift 2 ;;
    --own-token) own=true; shift ;;
    --set-token) set_token=true; shift ;;
    --replace) replace=true; shift ;;
    -*) usage ;;
    *) [ -z "$ws" ] || usage; ws=$1; shift ;;
  esac
done
[ -n "$ws" ] || usage
[[ "$ws" =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$ ]] || { echo "thryx: '$ws' is not a workspace slug (the last part of its MCP URL)" >&2; exit 2; }
[ -z "$var" ] || [[ "$var" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || { echo "thryx: '$var' is not an environment variable name" >&2; exit 2; }

case $client in
  claude|codex) ;;
  *) echo "thryx: --client must be claude or codex" >&2; exit 2 ;;
esac

# Codex's HTTP MCP configuration stores a bearer token variable name.
# Register it without reading the variable; the user sets it before starting Codex.
if [ "$client" = codex ]; then
  if $own || $set_token; then
    echo "thryx: Codex uses environment tokens; use --token-var NAME for a workspace-specific token and rotate its value outside the chat" >&2
    exit 2
  fi
  command -v codex >/dev/null 2>&1 || { echo "thryx: the codex command was not found" >&2; exit 1; }
  name="thryx-$ws"
  url="https://app.thryx.io/api/v1/mcp/$ws"
  var=${var:-THRYX_TOKEN}
  if codex mcp get "$name" >/dev/null 2>&1 && ! $replace; then
    echo "$name is already configured in Codex; use --replace to change its URL or token variable."
    exit 0
  fi
  # add updates an existing entry; do not remove it before a possibly failing add.
  codex mcp add "$name" --url "$url" --bearer-token-env-var "$var" >/dev/null \
    || { echo "thryx: codex mcp add failed for $name" >&2; exit 1; }
  echo "Configured $name ($url) in Codex; its token comes from \$$var."
  echo "Set $var outside the chat before starting Codex (Account settings -> API tokens)."
  echo "Start a new Codex session; /mcp shows whether the server connected."
  echo "For each repository using it, add 'ThryX workspace: $ws' to AGENTS.md."
  exit 0
fi

command -v claude >/dev/null 2>&1 || { echo "thryx: the claude command was not found" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "thryx: jq is required" >&2; exit 1; }

name="thryx-$ws"
url="https://app.thryx.io/api/v1/mcp/$ws"
service=thryx-mcp

if [ -z "$var" ] && command -v security >/dev/null 2>&1; then
  mode="keychain"
  account=shared
  $own && account=$ws
else
  mode="env"
  var=${var:-THRYX_TOKEN}
fi

if [ "$mode" = keychain ]; then
  if $set_token || ! security find-generic-password -s "$service" -a "$account" >/dev/null 2>&1; then
    command -v osascript >/dev/null 2>&1 || { echo "thryx: osascript is needed to ask for the token; use --token-var instead" >&2; exit 1; }
    if [ "$account" = shared ]; then who="your ThryX workspaces"; else who="the ThryX workspace $ws"; fi
    # The dialog runs outside the conversation: the token goes from the
    # dialog to the Keychain and is never printed.
    token=$(osascript \
      -e 'on run argv' \
      -e 'text returned of (display dialog ("Paste an API token for " & item 1 of argv & ". Get one from Account settings > API tokens in the ThryX web app. It is stored in your login Keychain as thryx-mcp.") default answer "" with hidden answer with title "ThryX" buttons {"Cancel", "Save"} default button "Save")' \
      -e 'end run' "$who" 2>/dev/null) || { echo "No token entered; nothing changed."; exit 1; }
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
    echo "Get a token from Account settings -> API tokens in the ThryX web app, then add"
    echo "this to your shell profile (for example ~/.zshrc) and restart Claude Code:"
    echo ""
    echo "  export $var='<your token>'"
    echo ""
    echo "Then run this again. Don't paste the token into the chat."
    exit 1
  fi
  helper="printf '{\"Authorization\": \"Bearer %s\"}' \"\$$var\""
  source_desc="\$$var"
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
    exit 0
  fi
  claude mcp remove "$name" >/dev/null || { echo "thryx: could not remove the existing $name; remove it with 'claude mcp remove $name --scope <scope>'" >&2; exit 1; }
  echo "Removed the existing $name."
fi

json=$(jq -nc --arg url "$url" --arg helper "$helper" '{type: "http", url: $url, headersHelper: $helper}') || exit 1
claude mcp add-json --scope user "$name" "$json" >/dev/null || { echo "thryx: claude mcp add-json failed for $name" >&2; exit 1; }

echo "Connected $name ($url) at user scope; its token comes from $source_desc."
echo "Restart Claude Code to load its tools; /mcp then shows whether it connected."
echo "With more than one ThryX workspace connected, add 'ThryX workspace: $ws' to"
echo "the CLAUDE.md of each repository that uses it."

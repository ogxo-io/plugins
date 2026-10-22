#!/usr/bin/env bash
# Run one task as a headless `claude -p --bare` billed to an Anthropic API key
# instead of the Claude subscription the session is signed in with.
# Arguments come on stdin, so the task text arrives verbatim, quotes and all:
#   key                  store or replace the API key (macOS Keychain dialog)
#   status (or nothing)  show where the key comes from
#   [options] [--] task  run the task
# Options: --model <id|alias> (default claude-opus-5-5), --effort
# low|medium|high|xhigh|max (default high), --budget <usd> (default 5),
# --write (also allow Edit and Write), --tools "<tool list>" (replaces the
# default read-only list).
# Key sources, first match wins: OGXO_ROUTE_API_KEY, then the login Keychain
# item ogxo-route-api-key. A parent ANTHROPIC_API_KEY is not used.
set -uo pipefail

service=ogxo-route-api-key
account=default
usage() {
  echo "usage: api key | status | [--model m] [--effort e] [--budget usd] [--write] [--tools \"list\"] [--] <task>" >&2
  exit 2
}

keychain_has() {
  command -v security >/dev/null 2>&1 && security find-generic-password -s "$service" -a "$account" >/dev/null 2>&1
}

input=$(cat)
input=${input#"${input%%[![:space:]]*}"}
input=${input%"${input##*[![:space:]]}"}

case "$input" in
  key)
    if ! command -v security >/dev/null 2>&1 || ! command -v osascript >/dev/null 2>&1; then
      echo "ogxo-route: the Keychain dialog needs macOS; export OGXO_ROUTE_API_KEY instead" >&2
      exit 1
    fi
    # The dialog runs outside the conversation: the key goes from the dialog
    # to the Keychain and is never printed.
    key=$(osascript \
      -e 'text returned of (display dialog "Paste an Anthropic API key (sk-ant-api...). /ogxo-route:api runs bill to it instead of your Claude subscription. It is stored in your login Keychain as ogxo-route-api-key." default answer "" with hidden answer with title "ogxo-route" buttons {"Cancel", "Save"} default button "Save")' \
      2>/dev/null) || { echo "No key entered; nothing changed."; exit 1; }
    [ -n "$key" ] || { echo "No key entered; nothing changed."; exit 1; }
    security add-generic-password -U -s "$service" -a "$account" -l "ogxo-route API key" -w "$key" >/dev/null 2>&1 \
      || { echo "ogxo-route: could not store the key in the Keychain" >&2; exit 1; }
    unset key
    echo "Stored the key in your login Keychain ($service)."
    exit 0
    ;;
  status | "")
    if [ -n "${OGXO_ROUTE_API_KEY:-}" ]; then
      echo "API key: from OGXO_ROUTE_API_KEY"
    elif keychain_has; then
      echo "API key: from your login Keychain ($service)"
    else
      echo "API key: none. Run /ogxo-route:api key (macOS) or export OGXO_ROUTE_API_KEY."
    fi
    exit 0
    ;;
esac

command -v jq >/dev/null 2>&1 || { echo "ogxo-route: jq is required" >&2; exit 1; }
command -v claude >/dev/null 2>&1 || { echo "ogxo-route: claude is not on PATH" >&2; exit 1; }

# Options are leading --flag tokens; the rest is the task.
model=claude-opus-5-5
effort=high
budget=5
write=false
tools="Read Grep Glob Bash(git diff *) Bash(git log *) Bash(git show *) Bash(git status *)"
while :; do
  input=${input#"${input%%[![:space:]]*}"}
  if [[ "$input" =~ ^--write($|[[:space:]]) ]]; then
    write=true
    input=${input#--write}
  elif [[ "$input" =~ ^--tools[[:space:]]+\"([^\"]*)\" ]] || [[ "$input" =~ ^--tools[[:space:]]+([^[:space:]]+) ]]; then
    tools=${BASH_REMATCH[1]}
    input=${input#"${BASH_REMATCH[0]}"}
  elif [[ "$input" =~ ^--(model|effort|budget)[[:space:]]+([^[:space:]]+) ]]; then
    case ${BASH_REMATCH[1]} in
      model) model=${BASH_REMATCH[2]} ;;
      effort) effort=${BASH_REMATCH[2]} ;;
      budget) budget=${BASH_REMATCH[2]} ;;
    esac
    input=${input#"${BASH_REMATCH[0]}"}
  elif [[ "$input" =~ ^--($|[[:space:]]) ]]; then
    input=${input#--}
    break
  elif [[ "$input" =~ ^-- ]]; then
    usage
  else
    break
  fi
done
task=${input#"${input%%[![:space:]]*}"}
[ -n "$task" ] || usage
[[ "$model" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "ogxo-route: bad model '$model'" >&2; usage; }
[[ "$effort" =~ ^(low|medium|high|xhigh|max)$ ]] || { echo "ogxo-route: effort must be low, medium, high, xhigh, or max" >&2; usage; }
[[ "$budget" =~ ^[0-9]+(\.[0-9]+)?$ ]] || { echo "ogxo-route: budget must be a dollar amount" >&2; usage; }
if $write; then tools="$tools Edit Write"; fi

key=${OGXO_ROUTE_API_KEY:-}
if [ -z "$key" ] && keychain_has; then
  key=$(security find-generic-password -s "$service" -a "$account" -w 2>/dev/null)
fi
[ -n "$key" ] || { echo "ogxo-route: no API key. Run /ogxo-route:api key (macOS) or export OGXO_ROUTE_API_KEY." >&2; exit 1; }

# --bare skips CLAUDE.md discovery, so the project's CLAUDE.md goes in with
# the brief.
brief=$(mktemp) || exit 1
out=$(mktemp) || { rm -f "$brief"; exit 1; }
trap 'rm -f "$brief" "$out"' EXIT
top=$(git rev-parse --show-toplevel 2>/dev/null) || top=$PWD
{
  echo "You were dispatched by another Claude Code session as a worker. It reads only your final message: put your findings or a summary of your changes there, with file:line references. Do not run git commands that change state. If a tool you need is not allowed, say so in your final message instead of working around it."
  if [ -f "$top/CLAUDE.md" ]; then
    printf '\n# Project instructions (%s/CLAUDE.md)\n\n' "$top"
    cat "$top/CLAUDE.md"
  fi
} >"$brief"

# --bare reads Anthropic auth only from ANTHROPIC_API_KEY or an apiKeyHelper,
# never the OAuth login or Keychain session, so the run cannot fall back to
# the subscription. The other token variables are cleared all the same.
env -u ANTHROPIC_AUTH_TOKEN -u CLAUDE_CODE_OAUTH_TOKEN ANTHROPIC_API_KEY="$key" \
  claude -p --bare \
  --model "$model" --effort "$effort" --max-budget-usd "$budget" \
  --permission-mode dontAsk --allowedTools "$tools" \
  --append-system-prompt-file "$brief" \
  --output-format json \
  "$task" </dev/null >"$out"
code=$?
unset key

if ! jq -e 'type == "object"' "$out" >/dev/null 2>&1; then
  echo "ogxo-route: claude exited $code without a JSON result" >&2
  cat "$out" >&2
  exit 1
fi
jq -r '.result // empty' "$out"
jq -r --arg m "$model" --arg e "$effort" --arg b "$budget" '
  "\n---\nogxo-route api: \($m) at \($e) effort, $\(.total_cost_usd // 0) of a $\($b) budget, \(.num_turns // 0) turns, \(((.duration_ms // 0) / 1000) | floor)s"
  + (if (.terminal_reason // "") != "" and .terminal_reason != "completed" then ", ended: \(.terminal_reason)" else "" end)
  + (if ((.permission_denials // []) | length) > 0 then "\ndenied tools: \([.permission_denials[].tool_name] | unique | join(", "))" else "" end)' "$out"
if [ "$code" -ne 0 ] || jq -e '.is_error == true' "$out" >/dev/null 2>&1; then
  exit 1
fi

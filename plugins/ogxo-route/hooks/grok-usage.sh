#!/usr/bin/env bash
# Started in the background by dash-event.sh under Grok Build. Grok writes a
# session's usage.json (token totals and cost by model) as the turn or the
# worker finishes, at about the moment its Stop or SubagentStop hook runs, so
# this waits up to 8 seconds for the file to be rewritten, then appends one
# `use` event to the board.
#   grok-usage.sh <usage.json> <board dir> <stamp file> [worker id]
# Without a worker id it records what the main session's totals grew by since
# the last turn (snapshot in use.grok, under a lock so two turns ending
# together don't count the same tokens); with one, the worker's totals.
set -u
f=$1 dir=$2 stamp=$3 id=${4:-}
# OGXO_ROUTE_USAGE_POLLS: how many half-second checks (tests shorten it).
for _ in $(seq 1 "${OGXO_ROUTE_USAGE_POLLS:-16}"); do
  [ -n "$(find "$f" -newer "$stamp" 2>/dev/null)" ] && break
  sleep 0.5
done
rm -f "$stamp"
[ -f "$f" ] && [ -f "$dir/events.js" ] || exit 0
# Totals by model as {in, out, cr, cw5, cw1, c}: input without the cached
# part (Grok's inputTokens includes cachedReadTokens), and the cost Grok
# computed, from costUsdTicks at 10^10 ticks per US dollar (xAI's unit).
# shellcheck disable=SC2016 # jq variables, not shell ones
gdef='def num: if type == "number" then . else 0 end;
  def guse: (.session.modelUsage | if type == "object" then . else {} end)
    | with_entries(.value |= ((.cachedReadTokens | num) as $cr
        | {in: ([(.inputTokens | num) - $cr, 0] | max), out: (.outputTokens | num), cr: $cr,
           cw5: (.cacheCreationTokens | num), cw1: 0, c: ((.costUsdTicks | num) / 1e10)}));'
if [ -n "$id" ]; then
  ev=$(jq -c --arg id "$id" "$gdef"'guse | select(. != {}) | {t: (now * 1000 | floor), e: "use", id: $id, use: .}' "$f" 2>/dev/null)
  [ -n "$ev" ] || exit 0
  printf 'E(%s);\n' "$ev" >>"$dir/events.js"
  # Remember the worker's models: see the main-session note below.
  jq -r '.use | keys[]' <<<"$ev" >>"$dir/use.kidmodels" 2>/dev/null
  exit 0
fi
lock="$dir/use.lock"
for _ in $(seq 1 40); do mkdir "$lock" 2>/dev/null && break; sleep 0.25; done
[ -d "$lock" ] || exit 0
prev=$(cat "$dir/use.grok" 2>/dev/null)
case $prev in '{'*'}') ;; *) prev='{}' ;; esac
# A worker pinned to another model ([subagents.models]) is also counted in
# the parent session's totals under that model, while one on the session's
# model is not (Grok 1.0.46). So the main session counts its primary model,
# and another model only when no worker used it.
kids=$(sort -u "$dir/use.kidmodels" 2>/dev/null | jq -R . | jq -sc . 2>/dev/null)
case $kids in '['*']') ;; *) kids='[]' ;; esac
ue=$(jq -c --argjson prev "$prev" --argjson kids "$kids" "$gdef"'
  (.session.primaryModelId // "") as $pm
  | guse | with_entries(select(.key == $pm or ((.key | IN($kids[])) | not))) as $n
  | {now: $n, d: ($n | with_entries(.key as $k | .value |= with_entries(.key as $g | .value -= (($prev[$k] // {})[$g] // 0)))
      | with_entries(select([.value[] | select(. > 0)] | length > 0)))}' "$f" 2>/dev/null)
case $ue in '{'*'}')
  jq -c '.now' <<<"$ue" >"$dir/use.grok"
  ev=$(jq -c 'select(.d != {}) | {t: (now * 1000 | floor), e: "use", use: .d}' <<<"$ue")
  [ -n "$ev" ] && printf 'E(%s);\n' "$ev" >>"$dir/events.js"
  ;;
esac
rmdir "$lock" 2>/dev/null
exit 0

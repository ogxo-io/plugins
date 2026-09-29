#!/usr/bin/env bash
# PreToolUse (Agent|Task): when Explore, general-purpose or Plan (or a bare
# dispatch, which is general-purpose) is dispatched with no model, add a note
# for Claude. It never sets a permission decision, so the dispatch always
# runs; the note arrives after it starts and steers the next dispatch.
command -v jq >/dev/null 2>&1 || { echo "ogxo-route/generic-warn: jq not found; this hook is inactive. Install jq to enable it." >&2; exit 1; }

jq -c '
  (.tool_input.subagent_type // "") as $raw
  | (if $raw == "" then "general-purpose" else $raw end) as $t
  | (.tool_input.model // "") as $m
  | if (["general-purpose", "Explore", "Plan"] | any(. == $t)) and $m == "" then
      {hookSpecificOutput: {
        hookEventName: "PreToolUse",
        additionalContext: ("ogxo-route: this " + $t + " dispatch has no model, so it runs on the session model. For listing or mechanical work pass model=haiku, for judgement pass model=sonnet, or use an ogxo-route worker (scout, test-runner, log-extractor). The dispatch already started; apply this to the next one.")
      }}
    else empty end
' 2>/dev/null
exit 0

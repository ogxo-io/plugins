#!/usr/bin/env bash
# All board events (prompt, stop, end, subagent start/stop, tool calls,
# permission requests and prompt notifications, advisor calls): when
# /ogxo-route:dashboard has turned the board on for this session, append one
# `E(<json>);` line to ${CLAUDE_PLUGIN_DATA}/dash/<session_id>/events.js for
# the page next to it. Records tool names, short summaries (paths, the first
# words of a command, a pattern or host), agent metadata, and for a failed
# tool call the last line of its error (140 characters at most); prompt
# text, file contents and successful tool output are not copied. Runs on
# every tool call, so it exits in pure bash unless this session's board is
# on: first when no board is on anywhere, then when this session's own flag
# is missing, so other sessions' boards don't make it start jq. Prints nothing; exits 0.
# The early exits still drain stdin: exiting with a large payload unread
# (a Write's content) leaves Claude Code writing into a closed pipe (EPIPE).
[ -n "${CLAUDE_PLUGIN_DATA:-}" ] || { cat >/dev/null; exit 0; }
compgen -G "$CLAUDE_PLUGIN_DATA/dash/*/on" >/dev/null 2>&1 || { cat >/dev/null; exit 0; }
in=$(cat)
# Claude Code puts session_id first in the payload, so the first match is it.
# jq re-reads it below and that value decides where the event is written.
sre='"session_id"[[:space:]]*:[[:space:]]*"([A-Za-z0-9_-]{1,128})"'
[[ $in =~ $sre ]] || exit 0
[ -f "$CLAUDE_PLUGIN_DATA/dash/${BASH_REMATCH[1]}/on" ] || exit 0
# dash.sh needs jq to turn a board on, so no jq means nothing to record.
command -v jq >/dev/null 2>&1 || exit 0

vdef='def verdict: if type == "string"
  then [match("VERDICT:\\**\\s*\\**\\s*(PASS|FAIL|RISKY)\\b"; "g")] | last | .captures[0].string
  else null end;'

# Token usage per model from assistant messages. A message's usage lists its
# iterations when the advisor ran inside it (type advisor_message, with its
# own model); otherwise the usage itself is one iteration. Cache writes are
# split into 1-hour and 5-minute entries because they are priced apart.
# shellcheck disable=SC2016 # jq variables, not shell ones
udef='def num: if type == "number" then . else 0 end;
  def rows: (.usage | if type == "object" then . else {} end) as $u
    | ((.model // "unknown") | tostring) as $mm
    | (if ($u.iterations | type) == "array" and ($u.iterations | length) > 0 then $u.iterations[] else $u end)
    | objects
    | ((.cache_creation | if type == "object" then .ephemeral_1h_input_tokens else 0 end) | num) as $c1
    | {k: (if .type == "advisor_message" then "adv:" + ((.model // "advisor") | tostring) else $mm end),
       in: (.input_tokens | num), out: (.output_tokens | num), cr: (.cache_read_input_tokens | num),
       cw1: $c1, cw5: ([((.cache_creation_input_tokens | num) - $c1), 0] | max)}
    | select(.in + .out + .cr + .cw1 + .cw5 > 0);
  def bucket: reduce .[] as $r ({}; .[$r.k] |= {in: ((.in // 0) + $r.in), out: ((.out // 0) + $r.out),
    cr: ((.cr // 0) + $r.cr), cw5: ((.cw5 // 0) + $r.cw5), cw1: ((.cw1 // 0) + $r.cw1)});'

# Line 1: session id (empty unless valid). Line 2: the event JSON or null.
# Line 3: the subagent transcript path, SubagentStop only.
out=$(jq -r --arg sq "'" "$vdef"'
  def str: if type == "string" then . else "" end;
  def obj: if type == "object" then . else {} end;
  def cap($n): str | if length > $n then .[0:$n] else . end;
  def rel($cwd): str | if $cwd != "" and startswith($cwd + "/") then .[($cwd | length) + 1:] else . end;
  def quoted: "\"[^\"]*\"|" + $sq + "[^" + $sq + "]*" + $sq;
  def word: "[A-Za-z][A-Za-z0-9_-]*";
  def name: str | if startswith("mcp__") then
      ((capture("^mcp__(?<s>.+?)__(?<t>.+)$") // null) as $m
       | if $m then ($m.s | sub("^plugin_[^_]+_"; "") | sub("^claude_ai_"; "")) + ":" + $m.t else . end)
    else . end;
  def reason: if (.interrupt | type) == "string" then "interrupted: " + (.interrupt | cap(40))
    else (.error | str | gsub("\u001b\\[[0-9;?]*[A-Za-z]"; "")) as $e
      | (($e | capture("^Exit code (?<c>[0-9]+)")) // null) as $x
      | ([$e | split("\n")[] | gsub("^\\s+|\\s+$"; "") | select(. != "" and (test("^Exit code [0-9]+$") | not))] | last // "") as $l
      | (if $x then "exit " + $x.c + (if $l != "" then ": " else "" end) else "" end) + $l | cap(140) end;
  def host: str | sub("^[A-Za-z][A-Za-z0-9+.-]*://"; "") | sub("[/?#].*$"; "") | sub("^.*@"; "") | sub(":[0-9]*$"; "");
  # Bash: drop leading VAR=value assignments and a leading `cd <dir> &&`.
  def strip: ("^(?:[A-Za-z_][A-Za-z0-9_]*=(?:" + quoted + "|[^\\s\"" + $sq + "]*)\\s+)+") as $env
    | str | sub("^\\s+"; "") | sub($env; "")
    | sub("^cd\\s+(?:" + quoted + "|[^\\s;&|]+)\\s*&&\\s*"; "") | sub($env; "");
  def bashinfo: strip as $c
    | if ($c | test("grok-bridge\\.mjs")) then
        (($c | capture("grok-bridge\\.mjs\\S*\\s+(?<w>" + word + ")")) // {w: null}).w as $w
        | (if $w == "run" then
             (($c | capture("grok-bridge\\.mjs\\S*\\s+run\\b.*?(?:\"(?<b>(?:[^\"\\\\]|\\\\.)*)\"|" + $sq + "(?<c>[^" + $sq + "]*)" + $sq + ")")) // null) as $m
             | if $m then " \"" + (($m.b // $m.c) | cap(60)) + "\"" else "" end
           else "" end) as $brief
        | {s: ("grok-bridge" + (if $w then " " + $w else "" end) + $brief), x: "grok"}
      elif ($c | test("codex-companion\\.mjs")) then
        {s: ("codex" + ((($c | capture("codex-companion\\.mjs\\S*\\s+(?<w>" + word + ")")) // {w: null}).w | if . then " " + . else "" end)), x: "codex"}
      elif ($c | test("(?:^|[;&|(]\\s*)(?:\\S*/)?codex(?:\\s|$)")) then
        {s: ("codex" + ((($c | capture("(?:^|[;&|(]\\s*)(?:\\S*/)?codex\\s+(?<w>" + word + ")")) // {w: null}).w | if . then " " + . else "" end)), x: "codex"}
      else {s: ([$c | splits("\\s+") | select(. != "")] | .[0:2] | join(" ")), x: null} end;
  def info($i; $cwd): .tool_name as $n
    | if (["Read", "Edit", "Write", "MultiEdit"] | any(. == $n)) then {s: ($i.file_path | rel($cwd))}
      elif $n == "NotebookEdit" then {s: ($i.notebook_path | rel($cwd))}
      elif $n == "Bash" then $i.command | bashinfo
      elif $n == "Grep" then {s: ($i.pattern | cap(40))}
      elif $n == "Glob" then {s: ($i.pattern | cap(60))}
      elif $n == "WebFetch" then {s: ($i.url | host)}
      elif $n == "WebSearch" then {s: ($i.query | cap(50))}
      elif $n == "Skill" then {s: ($i.skill | str)}
      else {s: ""} end
    | .s |= cap(80);

  (now * 1000 | floor) as $t
  | (.hook_event_name // "") as $h
  | (.tool_input | obj) as $i
  | (.cwd | str) as $cwd
  | (.agent_id // null) as $a
  | (.tool_use_id // null) as $u
  | ((.tool_name | str) as $n | ["Agent", "Task"] | any(. == $n)) as $agent
  | ((.agent_id | type) == "string" and .agent_id != "") as $hasid
  | (.session_id | str | if test("^[A-Za-z0-9_-]{1,128}$") then . else "" end),
    (if $h == "UserPromptSubmit" then {t: $t, e: "prompt"}
     elif $h == "Stop" then {t: $t, e: "stop"}
     elif $h == "SessionEnd" then {t: $t, e: "end"}
     elif $h == "SubagentStart" then
       if $hasid then {t: $t, e: "sstart", id: .agent_id, ty: (.agent_type // null)} else null end
     elif $h == "SubagentStop" then
       if $hasid then {t: $t, e: "sstop", id: .agent_id, ty: (.agent_type // null), v: (.last_assistant_message | verdict), out: null} else null end
     elif $h == "PreToolUse" and $agent then
       {t: $t, e: "dispatch", a: $a, u: $u,
        ty: ($i.subagent_type | str | if . == "" then "general-purpose" else . end),
        d: ($i.description | cap(120)), m: ($i.model // null), bg: ($i.run_in_background // false)}
     elif $h == "PreToolUse" then
       info($i; $cwd) as $f
       | {t: $t, e: "tool", a: $a, at: (.agent_type // null), u: $u, n: (.tool_name | name), s: $f.s}
         + (if $f.x then {x: $f.x} else {} end)
     elif $h == "PostToolUse" and $agent then
       (.tool_response | type == "object") as $o | (.tool_response | obj) as $r
       | {t: $t, e: "launched", a: $a, u: $u, id: ($r.agentId // null),
          ty: ($r.agentType // $i.subagent_type // "general-purpose"), rm: ($r.resolvedModel // null),
          d: ($r.description // $i.description | cap(120)),
          done: (if $o then $r.status == "completed" else null end),
          tc: ($r.totalToolUseCount // null), out: (($r.usage | obj | .output_tokens) // null)}
     elif $h == "PostToolUse" then {t: $t, e: "tool_ok", a: $a, u: $u, n: (.tool_name | name)}
     elif $h == "PostToolUseFailure" then {t: $t, e: "tool_err", a: $a, u: $u, n: (.tool_name | name), r: reason}
     elif $h == "PermissionRequest" then {t: $t, e: "perm", a: $a, n: (.tool_name | name)}
     elif $h == "Notification" then {t: $t, e: "wait", a: $a, k: (.notification_type | cap(40))}
     else null end | tojson),
    # SubagentStop: the subagent transcript. Stop and a main-session dispatch:
    # the session transcript, scanned for new advisor calls.
    (if $h == "SubagentStop" then .agent_transcript_path
     elif $h == "Stop" or ($h == "PreToolUse" and $agent and ($hasid | not)) then .transcript_path
     else "" end | str | select(test("\n") | not) // "")
' <<<"$in" 2>/dev/null) || exit 0

sid=${out%%$'\n'*}
rest=${out#*$'\n'}
ev=${rest%%$'\n'*}
tp=""
case $rest in *$'\n'*) tp=${rest#*$'\n'} ;; esac

re='^[A-Za-z0-9_-]{1,128}$'
[[ $sid =~ $re ]] || exit 0
dir="$CLAUDE_PLUGIN_DATA/dash/$sid"
[ -f "$dir/on" ] || exit 0
case $ev in '{'*'}') ;; *) exit 0 ;; esac

# SubagentStop: output tokens from the transcript, and the verdict from its
# last text when last_assistant_message had none. Transcript lines repeat a
# message's usage once per content block, so each message id counts once.
case $ev in *'"e":"sstop"'*)
  if [ -n "$tp" ] && [ -f "$tp" ]; then
    size=$(wc -c <"$tp" 2>/dev/null)
    size=${size//[!0-9]/}
    if [ -n "$size" ] && [ "$size" -lt 52428800 ]; then
      ev2=$(jq -R -n -c --argjson ev "$ev" "$vdef $udef"'
        reduce (inputs | fromjson? | objects | select(.type == "assistant") | .message | objects) as $m
          ({ids: {}, anon: 0, txt: null, msgs: {}};
           (($m.usage | if type == "object" then .output_tokens else null end) | if type == "number" then . else 0 end) as $n
           | (if ($m.id | type) == "string" then .ids[$m.id] = ([.ids[$m.id] // 0, $n] | max) | .msgs[$m.id] = {model: $m.model, usage: $m.usage} else .anon += $n end)
           | ([$m.content[]? | objects | select(.type == "text") | .text | strings] | join("\n")) as $x
           | if $x != "" then .txt = $x else . end)
        | $ev + {v: ($ev.v // (.txt | verdict)), out: (.anon + ([.ids[]] | add // 0)), use: ([.msgs[] | rows] | bucket)}
      ' "$tp" 2>/dev/null)
      case $ev2 in '{'*'}') ev=$ev2 ;; esac
    fi
  fi
  ;;
esac

# Stop and main-session dispatches: advisor calls and token usage since the
# last scan. The
# advisor runs on the API side (a server_tool_use block named advisor in the
# transcript), so no tool hook sees it. Only complete lines past the saved
# byte offset are read, and each call id is counted once.
case $ev in *'"e":"stop"'* | *'"e":"dispatch"'*)
  if [ -n "$tp" ] && [ -f "$tp" ]; then
    off=$(cat "$dir/adv.off" 2>/dev/null)
    off=${off//[!0-9]/}
    off=${off:-0}
    size=$(wc -c <"$tp" 2>/dev/null)
    size=${size//[!0-9]/}
    if [ -n "$size" ] && [ "$size" -lt "$off" ]; then off=0; fi
    if [ -n "$size" ] && [ "$size" -gt "$off" ]; then
      # Read the new bytes once; piping a long transcript through several
      # tools costs a few hundred ms per pass. A partial last line (still
      # being written) is left for the next scan.
      chunk="$dir/adv.chunk.$$"
      if [ "$off" -eq 0 ]; then cat "$tp" >"$chunk" 2>/dev/null; else tail -c +"$((off + 1))" "$tp" >"$chunk" 2>/dev/null; fi
      used=$(wc -c <"$chunk")
      used=${used//[!0-9]/}
      if [ -n "$used" ] && [ "$used" -gt 0 ] && [ -n "$(tail -c 1 "$chunk")" ]; then
        part=$(tail -n 1 "$chunk" | wc -c)
        used=$((used - ${part//[!0-9]/}))
      fi
      if [ "${used:-0}" -gt 0 ]; then
        # grep first: jq parsing every line of a long transcript takes seconds.
        head -c "$used" "$chunk" | grep -F 'server_tool_use' | jq -R -r '
          fromjson? | objects | select(.type == "assistant")
          | (.timestamp | if type == "string" then (sub("\\.[0-9]+"; "") | fromdateiso8601? // null) else null end) as $ts
          | .message.content? | arrays | .[] | objects
          | select(.type == "server_tool_use" and .name == "advisor") | .id | strings
          | select(test("^[A-Za-z0-9_-]{1,128}$")) | "\(.) \($ts // "")"' 2>/dev/null |
          while read -r id ts; do
            grep -qxF "$id" "$dir/adv.ids" 2>/dev/null && continue
            printf '%s\n' "$id" >>"$dir/adv.ids"
            at=$(jq -nc --arg ts "$ts" '{t: (if $ts == "" then (now * 1000 | floor) else ($ts | tonumber * 1000) end), e: "advisor"}') || continue
            printf 'E(%s);\n' "$at" >>"$dir/events.js" 2>/dev/null
          done
        # Main-session token usage in the new lines, as one silent "use" event.
        # Each message's lines repeat its usage, so each id counts once; the
        # last id is kept so a message split across two scans isn't counted
        # twice. On a first scan of a transcript over 50 MB the history is
        # skipped and counting starts now ("usenote" tells the page).
        if [ "$off" -gt 0 ] || [ "$used" -lt 52428800 ]; then
          last=$(cat "$dir/use.last" 2>/dev/null)
          ue=$(head -c "$used" "$chunk" | grep -F '"usage"' | jq -R -n -c --arg last "$last" "$udef"'
            [inputs | fromjson? | objects | select(.type == "assistant") | .message | objects
             | select((.id | type) == "string" and .id != $last)] as $ms
            | ($ms | reduce .[] as $m ({}; .[$m.id] = $m)) as $by
            | {last: (($ms | last | .id) // $last), use: ([$by[] | rows] | bucket)}' 2>/dev/null)
          case $ue in '{'*'}')
            lid=$(jq -r '.last // empty' <<<"$ue" 2>/dev/null)
            [[ $lid =~ ^[A-Za-z0-9_-]{1,128}$ ]] && printf '%s\n' "$lid" >"$dir/use.last" 2>/dev/null
            uev=$(jq -c 'select(.use != {}) | {t: (now * 1000 | floor), e: "use", use: .use}' <<<"$ue" 2>/dev/null)
            [ -n "$uev" ] && printf 'E(%s);\n' "$uev" >>"$dir/events.js" 2>/dev/null
            ;;
          esac
        else
          printf 'E(%s);\n' "$(jq -nc '{t: (now * 1000 | floor), e: "usenote"}')" >>"$dir/events.js" 2>/dev/null
        fi
        printf '%s\n' "$((off + used))" >"$dir/adv.off" 2>/dev/null
      fi
      rm -f "$chunk"
    fi
  fi
  ;;
esac

printf 'E(%s);\n' "$ev" >>"$dir/events.js" 2>/dev/null
case $ev in *'"e":"end"'*) rm -f "$dir/on" 2>/dev/null ;; esac
exit 0

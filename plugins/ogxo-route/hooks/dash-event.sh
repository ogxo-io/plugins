#!/usr/bin/env bash
# All board events (prompt, stop, end, subagent start/stop, tool calls,
# permission requests and prompt notifications, advisor calls): when
# /ogxo-route:dashboard has turned the board on for this session, append one
# `E(<json>);` line to <boards>/<session_id>/events.js (hooks/boards.sh) for
# the page next to it. Records tool names, short summaries (paths, the first
# words of a command, a pattern or host), agent metadata, and for a failed
# tool call the last line of its error (140 characters at most); prompt
# text, file contents and successful tool output are not copied. Runs on
# every tool call, so it exits in pure bash unless this session's board is
# on: first when no board is on anywhere, then when this session's own flag
# is missing, so other sessions' boards don't make it start jq. Prints nothing; exits 0.
# The early exits still drain stdin: exiting with a large payload unread
# (a Write's content) leaves Claude Code writing into a closed pipe (EPIPE).
# shellcheck source=SCRIPTDIR/dump.sh
. "${BASH_SOURCE[0]%/*}/dump.sh"
# shellcheck source=SCRIPTDIR/boards.sh
. "${BASH_SOURCE[0]%/*}/boards.sh"
# A board turned on before 0.6.0 is still in this host's data folder; it
# keeps recording there until it is turned off.
legacy=""
[ -n "${CLAUDE_PLUGIN_DATA:-}" ] && [ -d "$CLAUDE_PLUGIN_DATA/dash" ] && [ ! -L "$CLAUDE_PLUGIN_DATA/dash" ] && legacy="$CLAUDE_PLUGIN_DATA/dash"
[ -n "$boards" ] || [ -n "$legacy" ] || { [ -n "${dumped:-}" ] || cat >/dev/null; exit 0; }
{ [ -n "$boards" ] && compgen -G "$boards/*/on" >/dev/null 2>&1; } ||
  { [ -n "$legacy" ] && compgen -G "$legacy/*/on" >/dev/null 2>&1; } ||
  { [ -n "${dumped:-}" ] || cat >/dev/null; exit 0; }
[ -n "${dumped:-}" ] || in=$(cat)
# Claude Code puts session_id first in the payload, so the first match is it.
# jq re-reads it below and that value decides where the event is written.
re='^[A-Za-z0-9_-]{1,128}$'
sre='"session_id"[[:space:]]*:[[:space:]]*"([A-Za-z0-9_-]{1,128})"'
[[ $in =~ $sre ]] || exit 0
# A Grok Build worker runs in a session of its own, which SubagentStart
# recorded under .kids/ with the board it belongs to: its events go there.
parent=""
broot=$boards
if [ -n "$boards" ] && [ -f "$boards/${BASH_REMATCH[1]}/on" ]; then :
elif [ -n "$legacy" ] && [ -f "$legacy/${BASH_REMATCH[1]}/on" ]; then broot=$legacy
else
  [ -n "$boards" ] && [ -f "$boards/.kids/${BASH_REMATCH[1]}" ] || exit 0
  read -r parent <"$boards/.kids/${BASH_REMATCH[1]}" || [ -n "$parent" ] || exit 0
  [[ $parent =~ $re ]] && [ -f "$boards/$parent/on" ] || exit 0
fi
# dash.sh needs jq to turn a board on, so no jq means nothing to record.
command -v jq >/dev/null 2>&1 || exit 0

# shellcheck source=SCRIPTDIR/jqdefs.sh
. "${BASH_SOURCE[0]%/*}/jqdefs.sh"

# Line 1: session id (empty unless valid). Line 2: the event JSON or null.
# Line 3: the subagent transcript path, SubagentStop only.
out=$(jq -r --arg sq "'" --arg parent "$parent" "$vdef"'
  def str: if type == "string" then . else "" end;
  def obj: if type == "object" then . else {} end;
  def cap($n): str | if length > $n then .[0:$n] else . end;
  def rel($cwd): str | if $cwd != "" and . == $cwd then "." elif $cwd != "" and startswith($cwd + "/") then .[($cwd | length) + 1:] else . end;
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
  # Grok Build: tool names and fields as Claude Code names them; events from
  # a worker session moved to the parent board under the worker id (its own
  # prompt, stop, and session end are dropped: they are not the parent ones);
  # a failed command, which arrives as PostToolUse with a non-zero exit_code,
  # recorded as a failure.
  def gtools: {"run_terminal_command": "Bash", "read_file": "Read", "search_replace": "Edit", "write": "Write",
    "list_dir": "Glob", "grep": "Grep", "spawn_subagent": "Agent", "web_fetch": "WebFetch", "web_search": "WebSearch",
    "get_command_or_subagent_output": "TaskOutput"};
  def norm: (if (.tool_name | type) == "string" then .tool_name |= (gtools[.] // .) else . end)
    | (if (.tool_input | type) == "object" then .tool_input |= (
         (if .file_path == null and (.target_file | type) == "string" then .file_path = .target_file else . end)
         | (if .path == null and (.target_directory | type) == "string" then .path = .target_directory else . end)
         | if .run_in_background == null and (.background | type) == "boolean" then .run_in_background = .background else . end)
       else . end)
    | (if .last_assistant_message == null and (.lastAssistantMessage | type) == "string" then .last_assistant_message = .lastAssistantMessage else . end)
    | (if (.subagentId | type) == "string" and .agent_id == null then .agent_id = .subagentId | .agent_type = (.agent_type // .subagentType) else . end)
    | (if $parent != "" then .agent_id = (.agent_id // .session_id) | .agent_type = (.agent_type // .subagentType) | .session_id = $parent
         | (if (.hook_event_name | IN("UserPromptSubmit", "Stop", "SessionEnd")) then .hook_event_name = "" else . end)
       else . end)
    | (if .hook_event_name == "PostToolUse" and (.tool_response | type) == "object"
         and (.tool_response.exit_code | type) == "number" and .tool_response.exit_code != 0
       then .hook_event_name = "PostToolUseFailure"
         | .error = ("Exit code \(.tool_response.exit_code)\n" + (.tool_response.output_for_prompt | str | sub("^exit: [0-9]+\n"; "")))
       else . end);
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
      elif $n == "Glob" then {s: (if $i.pattern != null then $i.pattern | cap(60) else $i.path | str | sub("/$"; "") | rel($cwd) end)}
      elif $n == "WebFetch" then {s: ($i.url | host)}
      elif $n == "WebSearch" then {s: ($i.query | cap(50))}
      elif $n == "Skill" then {s: ($i.skill | str)}
      else {s: ""} end
    | .s |= cap(80);

  norm
  | (now * 1000 | floor) as $t
  | (.hook_event_name // "") as $h
  | (.tool_input | obj) as $i
  | (.cwd | str | sub("/$"; "")) as $cwd
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
       | {t: $t, e: "launched", a: $a, u: $u,
          id: ($r.agentId // (($r.text | str | capture("subagent_id: (?<i>[A-Za-z0-9_-]{1,128})")) // {i: null}).i),
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
    (if $h == "SubagentStop" then (.agent_transcript_path // (if (.subagentId | type) == "string" then .transcript_path else null end))
     elif $h == "Stop" or ($h == "PreToolUse" and $agent and ($hasid | not)) then .transcript_path
     else "" end | str | select(test("\n") | not) // "")
' <<<"$in" 2>/dev/null) || exit 0

sid=${out%%$'\n'*}
rest=${out#*$'\n'}
ev=${rest%%$'\n'*}
tp=""
case $rest in *$'\n'*) tp=${rest#*$'\n'} ;; esac

[[ $sid =~ $re ]] || exit 0
dir="$broot/$sid"
[ -f "$dir/on" ] || exit 0
case $ev in '{'*'}') ;; *) exit 0 ;; esac

# Grok Build keeps a session's token totals and cost, by model, in usage.json
# next to its transcript (updates.jsonl); Claude Code transcripts carry usage
# per message instead and are read below.
gu=""
# It may not exist yet when the hook runs, so the path alone decides.
case $tp in */.grok/sessions/*/updates.jsonl) gu="${tp%/*}/usage.json" ;; esac
# usage_later [worker id]: read usage.json in the background once Grok has
# written it (hooks/grok-usage.sh).
usage_later() {
  local stamp
  stamp=$(mktemp "$dir/use.stamp.XXXXXX" 2>/dev/null) || return 0
  nohup bash "${BASH_SOURCE[0]%/*}/grok-usage.sh" "$gu" "$dir" "$stamp" "${1:-}" >/dev/null 2>&1 &
}

# A Grok worker's own session: remember which board its events belong to.
case $ev in *'"e":"sstart"'*)
  if [[ $in == *'"subagentId"'* ]] && [[ $ev =~ \"id\":\"([A-Za-z0-9_-]{1,128})\" ]]; then
    mkdir -p "$boards/.kids" 2>/dev/null && printf '%s\n' "$sid" >"$boards/.kids/${BASH_REMATCH[1]}" 2>/dev/null
  fi
  ;;
esac

# SubagentStop: output tokens from the transcript, and the verdict from its
# last text when last_assistant_message had none. Transcript lines repeat a
# message's usage once per content block, so each message id counts once.
# Each stop counts only what the transcript gained since the last read of
# it: bf.ids holds "<id> <bytes read> <last message id>" per worker, written
# here after each stop and by dash-backfill.sh, last line wins. So a worker
# continued with a follow-up message, or added by the backfill and then
# finished, adds only its new calls. A line still being written is left to
# the next read.
case $ev in *'"e":"sstop"'*)
  if [ -n "$gu" ]; then
    [[ $ev =~ \"id\":\"([A-Za-z0-9_-]{1,128})\" ]] && usage_later "${BASH_REMATCH[1]}"
  elif [ -n "$tp" ] && [ -f "$tp" ]; then
    size=$(wc -c <"$tp" 2>/dev/null)
    size=${size//[!0-9]/}
    if [ -n "$size" ] && [ "$size" -lt 52428800 ]; then
      skip=0 skipid=""
      if [ -f "$dir/bf.ids" ] && [[ $ev =~ \"id\":\"([A-Za-z0-9_-]{1,128})\" ]]; then
        read -r skip skipid < <(awk -v id="${BASH_REMATCH[1]}" '$1 == id {n = $2; m = $3} END {print n + 0, m}' "$dir/bf.ids" 2>/dev/null)
        skip=${skip//[!0-9]/}
        skip=${skip:-0}
      fi
      [ "$skip" -le "$size" ] || skip=0
      chunk="$dir/sstop.chunk.$$"
      tail -c +"$((skip + 1))" "$tp" >"$chunk" 2>/dev/null
      used=$(wc -c <"$chunk")
      used=${used//[!0-9]/}
      if [ -n "$used" ] && [ "$used" -gt 0 ] && [ -n "$(tail -c 1 "$chunk")" ]; then
        part=$(tail -n 1 "$chunk" | wc -c)
        used=$((used - ${part//[!0-9]/}))
      fi
      out2=$(head -c "${used:-0}" "$chunk" | jq -R -n -c --argjson ev "$ev" --arg skipid "$skipid" --argjson first "$([ "$skip" -eq 0 ] && echo true || echo false)" "$vdef $udef"'
        reduce (inputs | fromjson? | objects | select(.type == "assistant") | .message | objects
                | select($skipid == "" or .id != $skipid)) as $m
          ({ids: {}, anon: 0, txt: null, msgs: {}, seq: []};
           (($m.usage | if type == "object" then .output_tokens else null end) | if type == "number" then . else 0 end) as $n
           | (if ($m.id | type) == "string" then (if .ids | has($m.id) then . else .seq += [$m.id] end) | .ids[$m.id] = ([.ids[$m.id] // 0, $n] | max) | .msgs[$m.id] = {model: $m.model, usage: $m.usage} else .anon += $n end)
           | ([$m.content[]? | objects | select(.type == "text") | .text | strings] | join("\n")) as $x
           | if $x != "" then .txt = $x else . end)
        | ($ev + {v: ($ev.v // (.txt | verdict)), out: (.anon + ([.ids[]] | add // 0)), use: ([.msgs[] | rows] | bucket)} + (. as $s | [$s.seq[] | $s.msgs[.]] | ctxinfo($first))),
          (.seq | last // $skipid)
      ' 2>/dev/null)
      rm -f "$chunk"
      ev2=${out2%%$'\n'*}
      case $ev2 in '{'*'}')
        ev=$ev2
        lid=${out2#*$'\n'}
        lid=${lid//\"/}
        [[ $lid =~ ^[A-Za-z0-9_-]{1,128}$ ]] || lid=""
        if [[ $ev =~ \"id\":\"([A-Za-z0-9_-]{1,128})\" ]]; then
          printf '%s %s %s\n' "${BASH_REMATCH[1]}" "$((skip + ${used:-0}))" "$lid" >>"$dir/bf.ids" 2>/dev/null
        fi
        ;;
      esac
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
  if [ -n "$gu" ]; then
    # Grok: what the session's totals grew by, once the turn has ended.
    case $ev in *'"e":"stop"'*) usage_later ;; esac
  elif [ -n "$tp" ] && [ -f "$tp" ]; then
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
# A session that ends can be resumed: dash-resume.sh turns the board back on.
case $ev in *'"e":"end"'*)
  rm -f "$dir/on" 2>/dev/null; : >"$dir/resume" 2>/dev/null
  # Forget this board's Grok workers.
  for k in "$boards"/.kids/*; do
    [ -f "$k" ] && [ "$(cat "$k" 2>/dev/null)" = "$sid" ] && rm -f "$k"
  done
  ;;
esac
exit 0

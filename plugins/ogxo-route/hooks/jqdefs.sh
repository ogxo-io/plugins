#!/usr/bin/env bash
# jq definitions shared by hooks/dash-event.sh and scripts/dash-backfill.sh.
# Sourced; defines vdef (the VERDICT line of a reply) and udef (token usage).
# shellcheck disable=SC2034 # used by the scripts that source this file

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

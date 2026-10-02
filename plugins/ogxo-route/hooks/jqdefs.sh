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
  # ctxinfo($first): input is the messages of one worker, in order; $first
  # says they start at the beginning of the transcript. calls, the largest context
  # one call carried (input + cache read + cache write), and rw: the calls that
  # rewrote an expired cache. Such a call carries 100K tokens or more, writes
  # more than it reads, and reads less than half of what the call before it
  # carried (a call that only adds a large tool result reads all of it). A
  # transcript first call is a cold start, not a rewrite; the first call of a
  # later chunk has no call before it here, so it is judged without that test.
  def ctxinfo($first): [.[] | .usage | objects
      | {t: ((.input_tokens | num) + (.cache_read_input_tokens | num) + (.cache_creation_input_tokens | num)),
         r: (.cache_read_input_tokens | num), w: (.cache_creation_input_tokens | num)}] as $c
    | {calls: ($c | length), ctx: ([$c[].t] | max // 0),
       rw: ([range(0; $c | length) as $i | $c[$i]
             | select(.t >= 100000 and .w > .r
                 and (if $i == 0 then ($first | not) else .r < ($c[$i - 1].t / 2) end))] | length)};
  def bucket: reduce .[] as $r ({}; .[$r.k] |= {in: ((.in // 0) + $r.in), out: ((.out // 0) + $r.out),
    cr: ((.cr // 0) + $r.cr), cw5: ((.cw5 // 0) + $r.cw5), cw1: ((.cw1 // 0) + $r.cw1)});'

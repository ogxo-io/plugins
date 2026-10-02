#!/usr/bin/env bash
# Run a long command (a full test suite, an e2e run, a build) in the
# background and wait for it in calls that each end within the 5 minutes a
# prompt cache entry lasts. A call that blocks longer than that makes the next
# call rewrite the agent's whole context, so a runner waits with `wait`
# (default 100 s, never more than 110 s, so a call ends inside the Bash tool's
# default 2-minute timeout) and calls it again until it is done.
#   longrun.sh start <name> <command>   run <command> (through bash -c) from this directory
#   longrun.sh wait <name> [seconds]    wait up to that long, then print the state
#   longrun.sh status <name>            print the state without waiting
#   longrun.sh tail <name> [lines]      the last lines of the log (default 40)
#   longrun.sh stop <name>              stop the run and every process it started
# The run is its own process group (job control is on when it starts), so
# stop signals the whole group: TERM, then KILL after 5 seconds.
# State is in ${OGXO_LONGRUN_DIR:-${TMPDIR:-/tmp}/ogxo-longrun}/<name>/: cmd,
# log, pid, start, end and exit. Use a name that is specific to the task. The
# run has no time limit of its own; stop it when it should not go on.
# Prints what happened and exits 0, so the exit status of a failed test run
# is read from the text ("finished, exit 1"), not taken for a tool error.
set -uo pipefail

usage() {
  echo "usage: longrun.sh start <name> <command> | wait <name> [seconds] | status <name> | tail <name> [lines] | stop <name>" >&2
  exit 2
}

action=${1:-}
name=${2:-}
re='^[A-Za-z0-9_-]{1,64}$'
[[ $name =~ $re ]] || usage
case $action in start | wait | status | tail | stop) ;; *) usage ;; esac
base=${OGXO_LONGRUN_DIR:-${TMPDIR:-/tmp}/ogxo-longrun}
dir="${base%/}/$name"

now() { date +%s; }
# alive: the run's process is still there.
alive() {
  local p
  p=$(cat "$dir/pid" 2>/dev/null) || return 1
  [[ $p =~ ^[0-9]+$ ]] && kill -0 "$p" 2>/dev/null
}
# report: the state, with the log's end.
report() {
  local s e el code
  [ -f "$dir/start" ] || { echo "longrun $name: not started"; return 0; }
  s=$(cat "$dir/start")
  if [ -f "$dir/exit" ]; then
    e=$(cat "$dir/end" 2>/dev/null)
    code=$(cat "$dir/exit")
    el=$(( ${e:-$(now)} - s ))
    echo "longrun $name: finished, exit $code after ${el}s"
    tail -n 30 "$dir/log" 2>/dev/null
  elif alive; then
    el=$(( $(now) - s ))
    echo "longrun $name: still running after ${el}s ($(wc -l <"$dir/log" 2>/dev/null | tr -d ' ') log lines); call wait again"
    tail -n 5 "$dir/log" 2>/dev/null
  else
    el=$(( $(now) - s ))
    echo "longrun $name: the process ended without an exit code after ${el}s (stopped or killed)"
    tail -n 20 "$dir/log" 2>/dev/null
  fi
  return 0
}

case $action in
  start)
    [ $# -ge 3 ] || usage
    if [ ! -f "$dir/exit" ] && alive; then
      echo "longrun $name: already running; call wait or stop"
      exit 0
    fi
    rm -rf "$dir"
    mkdir -p "$dir" || { echo "longrun: cannot create $dir" >&2; exit 1; }
    cmd=${*:3}
    printf '%s\n' "$cmd" >"$dir/cmd"
    now >"$dir/start"
    : >"$dir/log"
    # The end time is written before the exit code, so a waiter that sees the
    # exit code finds the end time.
    # Job control puts the run in a process group of its own, whose id is its
    # pid, so stop can signal everything it started at any depth.
    set -m
    # shellcheck disable=SC2016 # the inner shell expands these, with the arguments after _
    nohup bash -c 'cd "$1" || exit 1; bash -c "$2" >"$3/log" 2>&1 </dev/null; c=$?; date +%s >"$3/end"; echo "$c" >"$3/exit"' _ "$PWD" "$cmd" "$dir" >/dev/null 2>&1 </dev/null &
    echo $! >"$dir/pid"
    set +m
    echo "longrun $name: started (pid $!), log $dir/log; call wait $name"
    ;;
  wait)
    secs=${3:-100}
    [[ $secs =~ ^[0-9]+$ ]] || secs=100
    max=${OGXO_LONGRUN_MAX_WAIT:-110}
    [[ $max =~ ^[0-9]+$ ]] || max=110
    [ "$secs" -le "$max" ] || secs=$max
    end=$(( $(now) + secs ))
    while [ -f "$dir/start" ] && [ ! -f "$dir/exit" ] && alive && [ "$(now)" -lt "$end" ]; do sleep 1; done
    report
    ;;
  status) report ;;
  tail)
    n=${3:-40}
    [[ $n =~ ^[0-9]+$ ]] || n=40
    [ -f "$dir/log" ] && tail -n "$n" "$dir/log"
    ;;
  stop)
    p=$(cat "$dir/pid" 2>/dev/null)
    # The group can outlive the run's own shell (a server the command left in
    # the background), so test the group, not the pid.
    if [[ $p =~ ^[0-9]+$ ]] && kill -0 -- "-$p" 2>/dev/null; then
      kill -TERM -- "-$p" 2>/dev/null
      for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 -- "-$p" 2>/dev/null || break; sleep 0.5; done
      if kill -0 -- "-$p" 2>/dev/null; then
        kill -KILL -- "-$p" 2>/dev/null
        echo "longrun $name: stopped (killed after 5 seconds)"
      else
        echo "longrun $name: stopped"
      fi
    else
      echo "longrun $name: not running"
    fi
    ;;
esac
exit 0

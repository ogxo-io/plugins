#!/usr/bin/env bash
# Sourced first by the hooks that read a payload. While the directory
# ${CLAUDE_PLUGIN_DATA}/hookdump exists, save each payload as received, with
# the variables that identify the host, so a new host's hook format can be
# checked against what the hooks expect. Values of other variables are not
# written. Remove the directory to stop. Sets $in to the payload; the hook
# then reads $in instead of stdin.
dump_dir="${CLAUDE_PLUGIN_DATA:-}/hookdump"
if [ -n "${CLAUDE_PLUGIN_DATA:-}" ] && [ -d "$dump_dir" ] && [ ! -L "$dump_dir" ]; then
  in=$(cat)
  f="$dump_dir/$(date +%s)-$$-$RANDOM"
  printf '%s\n' "$in" >"$f.json" 2>/dev/null
  {
    for v in CLAUDECODE CLAUDE_PLUGIN_ROOT CLAUDE_PLUGIN_DATA CLAUDE_PROJECT_DIR CLAUDE_CODE_SESSION_ID \
      GROK_HOOK_EVENT GROK_HOOK_NAME GROK_SESSION_ID GROK_PLUGIN_ROOT GROK_PLUGIN_DATA GROK_WORKSPACE_ROOT CODEX_HOME; do
      [ -n "${!v+x}" ] && printf '%s=%s\n' "$v" "${!v}"
    done
    printf 'names:'; compgen -e | grep -E '^(GROK|CODEX|CLAUDE)' | tr '\n' ' '; echo
    printf 'hook=%s ppid_comm=%s\n' "${BASH_SOURCE[1]##*/}" "$(ps -o comm= -p "$PPID" 2>/dev/null)"
  } >"$f.env" 2>/dev/null
  # shellcheck disable=SC2034 # read by the hook that sources this file
  dumped=1
fi

#!/usr/bin/env bash
# SessionStart: turn a session's route board back on when the session is
# resumed. A board that stopped because its session ended (SessionEnd in
# dash-event.sh, or the exited-owner sweep in dash.sh) keeps a `resume`
# marker; `/ogxo-route:dashboard off` removes it, so a board turned off on
# purpose stays off. Resuming keeps the session id, so the marker is found
# under the same board directory. Prints nothing; exits 0.
[ -n "${CLAUDE_PLUGIN_DATA:-}" ] || { cat >/dev/null; exit 0; }
compgen -G "$CLAUDE_PLUGIN_DATA/dash/*/resume" >/dev/null 2>&1 || { cat >/dev/null; exit 0; }
in=$(cat)
sre='"session_id"[[:space:]]*:[[:space:]]*"([A-Za-z0-9_-]{1,128})"'
[[ $in =~ $sre ]] || exit 0
sid=${BASH_REMATCH[1]}
[ -f "$CLAUDE_PLUGIN_DATA/dash/$sid/resume" ] || exit 0
CLAUDE_CODE_SESSION_ID=$sid bash "${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}/scripts/dash.sh" on "$sid" >/dev/null 2>&1
exit 0

#!/usr/bin/env bash
# SessionStart: turn a session's route board back on when the session is
# resumed. A board that stopped because its session ended (SessionEnd in
# dash-event.sh, or the exited-owner sweep in dash.sh) keeps a `resume`
# marker; `/ogxo-route:dashboard off` removes it, so a board turned off on
# purpose stays off. Resuming keeps the session id, so the marker is found
# under the same board directory. Prints nothing; exits 0.
# shellcheck source=SCRIPTDIR/dump.sh
. "${BASH_SOURCE[0]%/*}/dump.sh"
# shellcheck source=SCRIPTDIR/boards.sh
. "${BASH_SOURCE[0]%/*}/boards.sh"
# Boards made before 0.6.0 are in this host's data folder; resuming one
# turns recording on in the shared folder.
legacy=""
[ -n "${CLAUDE_PLUGIN_DATA:-}" ] && [ -d "$CLAUDE_PLUGIN_DATA/dash" ] && [ ! -L "$CLAUDE_PLUGIN_DATA/dash" ] && legacy="$CLAUDE_PLUGIN_DATA/dash"
{ [ -n "$boards" ] && compgen -G "$boards/*/resume" >/dev/null 2>&1; } ||
  { [ -n "$legacy" ] && compgen -G "$legacy/*/resume" >/dev/null 2>&1; } ||
  { [ -n "${dumped:-}" ] || cat >/dev/null; exit 0; }
[ -n "${dumped:-}" ] || in=$(cat)
sre='"session_id"[[:space:]]*:[[:space:]]*"([A-Za-z0-9_-]{1,128})"'
[[ $in =~ $sre ]] || exit 0
sid=${BASH_REMATCH[1]}
{ [ -n "$boards" ] && [ -f "$boards/$sid/resume" ]; } || { [ -n "$legacy" ] && [ -f "$legacy/$sid/resume" ]; } || exit 0
CLAUDE_CODE_SESSION_ID=$sid bash "${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}/scripts/dash.sh" on "$sid" >/dev/null 2>&1
exit 0

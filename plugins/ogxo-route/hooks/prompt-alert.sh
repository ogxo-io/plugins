#!/usr/bin/env bash
# Notification (permission_prompt|agent_needs_input): when alerts are on
# (/ogxo-route:alerts on), show a desktop notification that Claude Code is
# waiting, and optionally post a fixed message to a push URL. Off by default:
# does nothing unless ${CLAUDE_PLUGIN_DATA}/alerts.json has enabled: true.
# The push carries a fixed text only, never the prompt's message, which can
# include the command being asked about. Never fails the session.
command -v jq >/dev/null 2>&1 || exit 0
[ -n "${CLAUDE_PLUGIN_DATA:-}" ] || exit 0
state="$CLAUDE_PLUGIN_DATA/alerts.json"
jq -e '.enabled == true' "$state" >/dev/null 2>&1 || exit 0

input=$(cat)
msg=$(jq -r '.message // empty' <<<"$input" 2>/dev/null)
[ -n "$msg" ] || msg="Claude Code is waiting for you"

# Where and who: the title names the project (the main repository's folder,
# as the dashboard names it), the subtitle the worktree's folder when the
# session runs in a linked worktree, and the subagent asking, or "main session".
cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)
agent=$(jq -r '.agent_type // empty' <<<"$input" 2>/dev/null)
title="Claude Code"
wt=""
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  top=""
  common=""
  if command -v git >/dev/null 2>&1; then
    top=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || top=""
    common=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || common=""
  fi
  project=$(basename "${top:-$cwd}")
  if [ -n "$top" ] && [ -n "$common" ] && [ "$common" != "$top/.git" ]; then
    wt=$project
    project=$(basename "$(dirname "$common")")
  fi
  title="Claude Code · $project"
fi
sub=${agent:-main session}
[ -z "$wt" ] || sub="worktree $wt · $sub"

# terminal-notifier can bring the app that runs Claude Code forward on click
# (macOS exports its bundle id as __CFBundleIdentifier). An osascript
# notification belongs to Script Editor, so clicking it opens Script Editor.
# terminal-notifier fails (exit 3) until macOS allows its notifications, so
# osascript is also the fallback.
notify_osascript() {
  command -v osascript >/dev/null 2>&1 || return 1
  osascript -e 'on run argv' -e 'display notification (item 1 of argv) with title (item 2 of argv) subtitle (item 3 of argv) sound name "Glass"' -e 'end run' "$msg" "$title" "$sub" >/dev/null 2>&1
}
notify_terminal_notifier() {
  command -v terminal-notifier >/dev/null 2>&1 || return 1
  if [ -n "${__CFBundleIdentifier:-}" ]; then
    terminal-notifier -title "$title" -subtitle "$sub" -message "$msg" -sound Glass -activate "$__CFBundleIdentifier" >/dev/null 2>&1
  else
    terminal-notifier -title "$title" -subtitle "$sub" -message "$msg" -sound Glass >/dev/null 2>&1
  fi
}
if ! notify_terminal_notifier && ! notify_osascript && command -v notify-send >/dev/null 2>&1; then
  notify-send "$title" "$sub: $msg" >/dev/null 2>&1
fi

push=$(jq -r '.push_url // empty' "$state" 2>/dev/null)
if [ -n "$push" ] && command -v curl >/dev/null 2>&1; then
  curl -fsS -m 5 -d "Claude Code is waiting for a permission answer" "$push" >/dev/null 2>&1
fi
exit 0

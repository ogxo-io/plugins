#!/usr/bin/env bash
# Sourced by the hooks and scripts/dash.sh: the folder every host's boards
# live in, so Claude Code and Grok Build sessions share one hub and one
# server. Each host's own plugin data folder used to hold its boards;
# dash.sh moves them here once and leaves a link behind. Sets $boards, or
# leaves it empty when there is neither OGXO_ROUTE_BOARDS nor HOME.
boards=${OGXO_ROUTE_BOARDS:-}
if [ -z "$boards" ] && [ -n "${HOME:-}" ]; then boards="$HOME/.ogxo/route/boards"; fi

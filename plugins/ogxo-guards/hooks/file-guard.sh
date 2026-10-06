#!/usr/bin/env bash
# Reads Claude Edit/Write payloads, native Codex apply_patch payloads, and
# Codex Bash payloads whose command is a heredoc apply_patch.
set -uo pipefail
input=$(cat)
dir=$(cd "$(dirname "$0")" && pwd)
files=$(jq -c -f "$dir/patch-files.jq" <<<"$input") || exit 0
case "${1:-}" in
  paths)
    # Normalize dot segments before matching; include both rename endpoints.
    paths=$(jq -r --arg cwd "$(jq -r '.cwd // empty' <<<"$input")" '
      def normalize:
        split("/") | reduce .[] as $part ([];
          if $part == "" or $part == "." then .
          elif $part == ".." then if length > 0 then .[:-1] else . end
          else . + [$part] end) | "/" + join("/");
      .[] | (.path, (.destination // empty)) | select(length > 0) |
      (if startswith("/") then . else $cwd + "/" + . end) | normalize
    ' <<<"$files") || exit 1
    while IFS= read -r f; do
      case "$f" in
        */node_modules/*|*/vendor/*|*/.git/*|*package-lock.json|*yarn.lock|*pnpm-lock.yaml|*bun.lockb|*Cargo.lock|*go.sum|*Gemfile.lock|*poetry.lock|*uv.lock)
          echo "BLOCKED: $f is a generated or vendored file. Change the source (e.g. package.json) and regenerate instead." >&2
          exit 2 ;;
      esac
    done <<<"$paths"
    ;;
  size)
    sz=$(jq '[group_by(.path)[] | map(.added) | add] | max // 0' <<<"$files")
    if [ "$sz" -gt 1048576 ]; then
      echo "BLOCKED: Write content or added patch text of $sz characters exceeds the 1,048,576-character limit. Generate large files with a script instead." >&2
      exit 2
    fi
    ;;
  *) exit 1 ;;
esac

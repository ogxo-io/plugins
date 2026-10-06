#!/usr/bin/env bash
# Format each surviving patch destination, then report checks together.
set -uo pipefail
input=$(cat)
dir=$(cd "$(dirname "$0")" && pwd)
files=$(jq -c -f "$dir/patch-files.jq" <<<"$input") || exit 0
cwd=$(jq -r '.cwd // empty' <<<"$input")
# A cwd that is gone leaves absolute paths to format; relative ones are skipped.
incwd=1
[ -z "$cwd" ] || cd "$cwd" 2>/dev/null || incwd=0
problems=''
while IFS= read -r record; do
  f=$(jq -r '.destination // .path' <<<"$record")
  case "$f" in /*) ;; *) [ "$incwd" -eq 1 ] || continue ;; esac
  [ -n "$f" ] && [ -f "$f" ] || continue
  # A name starting with - must not reach a tool as an option.
  case "$f" in -*) f=./$f ;; esac
  case "$f" in
    *.js|*.jsx|*.ts|*.tsx|*.json|*.css|*.scss|*.md|*.html|*.yaml|*.yml) npx --no-install prettier --write "$f" >/dev/null 2>&1 || true ;;
    *.go) gofmt -w "$f" 2>/dev/null || true ;;
    *.rs) rustfmt "$f" 2>/dev/null || true ;;
    *.py) black --quiet "$f" 2>/dev/null || true ;;
  esac
  case "$f" in
    *.md|*.markdown|*.diff|*.patch) ;;
    *)
      lines=$(grep -nE '[[:blank:]]+$' "$f" 2>/dev/null | head -5)
      if [ -n "$lines" ]; then
        problems="${problems:+$problems
}Trailing whitespace in $f — remove it (line:content): $(printf '%s' "$lines" | tr '\n' ' ')"
      fi ;;
  esac
  case "$f" in
    *.yml|*.yaml)
      if python3 -c 'import yaml' 2>/dev/null; then
        err=$(python3 -c 'import sys,yaml
try:
    list(yaml.compose_all(open(sys.argv[1]), Loader=yaml.SafeLoader))
except yaml.YAMLError as e:
    print(e); sys.exit(1)' "$f" 2>&1) || problems="${problems:+$problems
}YAML syntax error in $f: $err"
      fi ;;
  esac
done < <(jq -c '[.[] | select(.kind != "delete")] | unique_by(.destination // .path)[]' <<<"$files")
[ -z "$problems" ] || { printf '%s\n' "$problems" >&2; exit 2; }

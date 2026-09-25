#!/usr/bin/env bash
# Install ogxo plugins into Claude Code.
#
#   curl -fsSL https://raw.githubusercontent.com/ogxo-io/plugins/main/install.sh | bash -s -- --list
#   curl -fsSL https://raw.githubusercontent.com/ogxo-io/plugins/main/install.sh | bash -s -- ogxo-git ogxo-review
#   curl -fsSL https://raw.githubusercontent.com/ogxo-io/plugins/main/install.sh | bash -s -- --all
#
# Adds the ogxo marketplace (or updates it when it is already added), then
# installs each named plugin, or updates it when it is already installed.
# --all installs the ogxo bundle plugin, whose dependencies are the whole set
# minus the opt-in plugins, so a plugin added to the set later arrives with the
# bundle's next update. The plugin list comes from the marketplace itself. It
# only runs `claude plugin` commands.
# No `set -u`: macOS runs this with /bin/bash 3.2, where an empty array is
# an unbound variable.
set -o pipefail

MARKETPLACE=ogxo
SOURCE=${OGXO_MARKETPLACE_SOURCE:-ogxo-io/plugins}
# The bundle plugin --all installs, and the plugins it leaves out unless asked
# for: thryx needs a Thryx account, ogxo-format rewrites every file Claude edits.
BUNDLE=ogxo
OPT_IN=(thryx ogxo-format)

usage() {
  cat <<'EOF'
Usage: install.sh [--list] [--all [--include-thryx] [--include-format]] [PLUGIN...]

  PLUGIN...          install these plugins, by name (for example ogxo-git)
  --all              install the ogxo bundle: every plugin except thryx
                     (needs a Thryx account) and ogxo-format (reformats every
                     file Claude edits). Same as `claude plugin install ogxo@ogxo`.
  --include-thryx    with --all, also install thryx
  --include-format   with --all, also install ogxo-format
  --list             show the plugins and which are installed, then exit
  -h, --help         show this help

Plugins already installed are updated to the latest version.
Set OGXO_MARKETPLACE_SOURCE to add the marketplace from another source.
EOF
}

say() { printf '%s\n' "$*"; }
die() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

all=false
include=()
list_only=false
names=()
for arg in "$@"; do
  case "$arg" in
    --all) all=true ;;
    --include-format) include+=(ogxo-format) ;;
    --include-thryx) include+=(thryx) ;;
    --list) list_only=true ;;
    -h | --help) usage; exit 0 ;;
    -*) usage >&2; die "unknown option: $arg" ;;
    *) names+=("$arg") ;;
  esac
done

if ! $all && ! $list_only && [ "${#names[@]}" -eq 0 ]; then
  usage
  say ""
  list_only=true
fi
if $all && [ "${#names[@]}" -gt 0 ]; then
  die "pass plugin names or --all, not both"
fi
if [ "${#include[@]}" -gt 0 ] && ! $all; then
  die "--include-thryx and --include-format go with --all; otherwise name the plugin"
fi

command -v claude >/dev/null 2>&1 || die "claude (Claude Code) is not on PATH; install it first: https://code.claude.com"
command -v jq >/dev/null 2>&1 || die "jq is required (brew install jq, apt install jq)"

# ── Marketplace ─────────────────────────────────────────
marketplaces=$(claude plugin marketplace list --json) || die "could not list marketplaces"
if jq -e --arg m "$MARKETPLACE" 'any(.[]; .name == $m)' >/dev/null <<<"$marketplaces"; then
  say "Updating the $MARKETPLACE marketplace..."
  claude plugin marketplace update "$MARKETPLACE" >/dev/null || die "could not update the $MARKETPLACE marketplace"
else
  say "Adding the $MARKETPLACE marketplace from $SOURCE..."
  claude plugin marketplace add "$SOURCE" >/dev/null || die "could not add the marketplace from $SOURCE"
fi

# ── Catalog and installed state ─────────────────────────
state=$(claude plugin list --available --json) || die "could not list plugins"
catalog=$(jq -r --arg m "$MARKETPLACE" '
  [ (.available[] | select(.marketplaceName == $m) | .name),
    (.installed[] | .id | select(endswith("@" + $m)) | sub("@[^@]*$"; "")) ]
  | unique[]' <<<"$state")
installed=$(jq -r --arg m "$MARKETPLACE" '.installed[] | .id | select(endswith("@" + $m)) | sub("@[^@]*$"; "")' <<<"$state")
[ -n "$catalog" ] || die "the $MARKETPLACE marketplace lists no plugins"

in_list() { grep -qxF -- "$1" <<<"$2"; }
is_opt_in() {
  local p
  for p in "${OPT_IN[@]}"; do [ "$p" = "$1" ] && return 0; done
  return 1
}

if $list_only; then
  say "Plugins in the $MARKETPLACE marketplace:"
  while IFS= read -r p; do
    notes=""
    in_list "$p" "$installed" && notes+=" (installed)"
    [ "$p" = "$BUNDLE" ] && notes+=" (bundle: installs every plugin except the opt-in ones; what --all installs)"
    is_opt_in "$p" && notes+=" (opt-in: not in the bundle)"
    say "  $p$notes"
  done <<<"$catalog"
  exit 0
fi

# ── Targets ─────────────────────────────────────────────
targets=()
if $all; then
  in_list "$BUNDLE" "$catalog" || die "the $MARKETPLACE marketplace has no $BUNDLE bundle"
  targets+=("$BUNDLE")
  for p in "${include[@]+"${include[@]}"}"; do
    in_list "$p" "$catalog" && targets+=("$p")
  done
else
  for p in "${names[@]}"; do
    p=${p%@"$MARKETPLACE"}
    in_list "$p" "$catalog" || die "no plugin named '$p' in the $MARKETPLACE marketplace (see --list)"
    targets+=("$p")
  done
fi

# ── Install or update ───────────────────────────────────
failed=()
done_list=()
for p in "${targets[@]}"; do
  if in_list "$p" "$installed"; then
    say "Updating $p..."
    action=update
  else
    say "Installing $p..."
    action=install
  fi
  if claude plugin "$action" "$p@$MARKETPLACE" >/dev/null; then
    done_list+=("$p")
  else
    failed+=("$p")
  fi
done

say ""
[ "${#done_list[@]}" -gt 0 ] && say "Done: ${done_list[*]}"
if $all; then
  for p in "${OPT_IN[@]}"; do
    in_list "$p" "$(printf '%s\n' "${include[@]+"${include[@]}"}")" && continue
    in_list "$p" "$catalog" && ! in_list "$p" "$installed" && say "Not in the bundle: $p (opt-in); add it with: install.sh $p"
  done
fi

# Next steps for plugins that need one.
for p in "${done_list[@]}"; do
  case "$p" in
    thryx) say "thryx: set THRYX_WORKSPACE and THRYX_TOKEN before starting Claude Code (see its README)." ;;
    ogxo-statusline | "$BUNDLE") say "ogxo-statusline: run /ogxo-statusline:setup in Claude Code to turn the status line on." ;;
  esac
done
say "Restart Claude Code, or run /reload-plugins, to load them."

if [ "${#failed[@]}" -gt 0 ]; then
  printf 'install.sh: failed: %s\n' "${failed[*]}" >&2
  exit 1
fi
exit 0

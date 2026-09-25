#!/usr/bin/env bash
# ogxo status line for Grok Build.
#
# Reads the session JSON that Grok writes to stdin and prints one line:
#   model │ context use │ directory (git branch, ahead/behind, changes) │
#   session time │ active turn │ effort │ session output and cache-read share │ cost
# Context percent and the token fraction are the live window (used_percentage
# and context_tokens / context_window_size). Output tokens and the cache
# percentage are session totals. The turn segment is local time since
# turn.started_at_ms and shows only while that field is present.
# Every value comes from stdin or local git; the script makes no network calls
# and reads no credentials. Grok does not send plan-usage windows, so there is
# no second line.
#
# Options (append them to the status-line command in config.toml):
#   --no-git          skip the git branch segment
#   --no-cache        skip session output tokens and the cache-read share
#   --cost=MODE       session cost: auto and always show it when Grok sends
#                     one; never hides it
#   --basic-colors    16-color ANSI instead of 24-bit color
#   --no-color        plain text (also when NO_COLOR is set)

set -f

show_git=true
show_cache=true
cost_mode=auto
palette=truecolor
[ -n "${NO_COLOR:-}" ] && palette=none

for arg in "$@"; do
    case "$arg" in
        --no-git) show_git=false ;;
        --no-usage) ;;
        --no-cache) show_cache=false ;;
        --cost=auto|--cost=always|--cost=never) cost_mode=${arg#--cost=} ;;
        --basic-colors) [ "$palette" = none ] || palette=basic ;;
        --no-color) palette=none ;;
    esac
done

input=$(cat)

if [ -z "$input" ] || ! command -v jq >/dev/null 2>&1; then
    printf 'ogxo'
    exit 0
fi

# ── Colors ──────────────────────────────────────────────
case "$palette" in
    truecolor)
        blue=$'\033[38;2;0;153;255m'
        orange=$'\033[38;2;255;176;85m'
        green=$'\033[38;2;0;175;80m'
        cyan=$'\033[38;2;86;182;194m'
        red=$'\033[38;2;255;85;85m'
        yellow=$'\033[38;2;230;200;0m'
        white=$'\033[38;2;220;220;220m'
        dim=$'\033[2m'
        reset=$'\033[0m'
        ;;
    basic)
        blue=$'\033[34m'
        orange=$'\033[33m'
        green=$'\033[32m'
        cyan=$'\033[36m'
        red=$'\033[31m'
        yellow=$'\033[93m'
        white=$'\033[37m'
        dim=$'\033[2m'
        reset=$'\033[0m'
        ;;
    *)
        blue='' orange='' green='' cyan='' red='' yellow='' white='' dim='' reset=''
        ;;
esac

sep=" ${dim}│${reset} "

# ── Read every field in one jq call ─────────────────────
# Fields are joined with the ASCII unit separator: tabs would collapse empty
# fields under `read`, and a missing field must stay an empty slot.
IFS=$'\x1f' read -r model size used_pct live_tok out_tok \
    sess_in sess_create sess_read \
    cwd duration_ms effort worktree cost_usd turn_started <<<"$(printf '%s' "$input" | jq -r '
    [ .model.display_name,
      .context_window.context_window_size,
      .context_window.used_percentage,
      .context_window.context_tokens,
      (.context_window.session_output_tokens // .context_window.session_usage.output_tokens),
      .context_window.session_usage.input_tokens,
      .context_window.session_usage.cache_creation_input_tokens,
      .context_window.session_usage.cache_read_input_tokens,
      (.workspace.current_dir // .cwd),
      .cost.total_duration_ms,
      .effort.level,
      (.workspace.git_worktree // .worktree.name),
      .cost.total_cost_usd,
      .turn.started_at_ms
    ] | map(if . == null then "" else tostring end) | join("\u001f")' 2>/dev/null)"

# ── Helpers ─────────────────────────────────────────────
to_int() {
    awk -v n="${1:-0}" 'BEGIN { printf "%d", n + 0.5 }'
}

format_tokens() {
    local num=$1
    if [ "$num" -ge 1000000 ]; then
        awk -v n="$num" 'BEGIN { printf "%.1fm", n / 1000000 }'
    elif [ "$num" -ge 1000 ]; then
        awk -v n="$num" 'BEGIN { printf "%.0fk", n / 1000 }'
    else
        printf '%d' "$num"
    fi
}

color_for_pct() {
    local pct=$1
    if [ "$pct" -ge 90 ]; then printf '%s' "$red"
    elif [ "$pct" -ge 70 ]; then printf '%s' "$yellow"
    elif [ "$pct" -ge 50 ]; then printf '%s' "$orange"
    else printf '%s' "$green"
    fi
}

format_duration() {
    local secs=$1
    if [ "$secs" -ge 3600 ]; then
        printf '%dh%dm' $(( secs / 3600 )) $(( (secs % 3600) / 60 ))
    elif [ "$secs" -ge 60 ]; then
        printf '%dm' $(( secs / 60 ))
    else
        printf '%ds' "$secs"
    fi
}

# ── Line 1: session ─────────────────────────────────────
[ -n "$model" ] || model="Grok"
[ -n "$cwd" ] || cwd=$(pwd)

line1="${blue}${model}${reset}"

if [ -n "$used_pct" ]; then
    pct=$(to_int "$used_pct")
    line1+="${sep}◔ $(color_for_pct "$pct")${pct}%${reset}"
    # context_tokens is the live window. Session totals are a different count
    # and are not folded into this fraction.
    if [ -n "$live_tok" ] && [ -n "$size" ]; then
        size_i=$(to_int "$size")
        if [ "$size_i" -gt 0 ]; then
            line1+=" ${dim}($(format_tokens "$(to_int "$live_tok")")/$(format_tokens "$size_i"))${reset}"
        fi
    fi
fi

line1+="${sep}${cyan}$(basename "$cwd")${reset}"
[ -n "$worktree" ] && line1+=" ${dim}[wt:${worktree}]${reset}"

if $show_git; then
    # One git call: branch, upstream ahead/behind, and changed entries.
    # --no-optional-locks keeps it from contending with other git commands.
    status=$(git --no-optional-locks -C "$cwd" status --porcelain=v2 --branch 2>/dev/null)
    if [ -n "$status" ]; then
        branch="" oid="" ahead=0 behind=0 changed=0
        while IFS= read -r row; do
            case "$row" in
                "# branch.head "*) branch=${row#\# branch.head } ;;
                "# branch.oid "*) oid=${row#\# branch.oid } ;;
                "# branch.ab "*)
                    set -- ${row#\# branch.ab }
                    ahead=${1#+}
                    behind=${2#-}
                    ;;
                "#"*) ;;
                ?*) changed=$(( changed + 1 )) ;;
            esac
        done <<<"$status"
        [ "$branch" = "(detached)" ] && branch=${oid:0:7}
        dirty=""
        [ "$changed" -gt 0 ] && dirty="*"
        line1+=" ${green}(${branch}${red}${dirty}${green})${reset}"
        if [ "$ahead" -gt 0 ] || [ "$behind" -gt 0 ]; then
            line1+=" "
            [ "$ahead" -gt 0 ] && line1+="${green}↑${ahead}${reset}"
            [ "$behind" -gt 0 ] && line1+="${red}↓${behind}${reset}"
        fi
        [ "$changed" -gt 0 ] && line1+=" ${orange}~${changed}${reset}"
    fi
fi

if [ -n "$duration_ms" ]; then
    line1+="${sep}${dim}⏱ ${reset}${white}$(format_duration $(( $(to_int "$duration_ms") / 1000 )))${reset}"
fi

if [ -n "$turn_started" ] && awk -v n="$turn_started" 'BEGIN { exit !(n + 0 >= 1) }'; then
    now_s=$(date +%s)
    started_s=$(( $(to_int "$turn_started") / 1000 ))
    if [ "$now_s" -ge "$started_s" ]; then
        line1+="${sep}${dim}turn ${reset}${white}$(format_duration $(( now_s - started_s )))${reset}"
    fi
fi

[ -n "$effort" ] && line1+=" ${dim}effort:${reset}${white}${effort}${reset}"

if $show_cache; then
    cache_seg=""
    [ -n "$out_tok" ] && cache_seg+="${dim}out:${reset}${white}$(format_tokens "$(to_int "$out_tok")")${reset}"
    if [ -n "$sess_read" ]; then
        read_i=$(to_int "$sess_read")
        in_i=0
        create_i=0
        [ -n "$sess_in" ] && in_i=$(to_int "$sess_in")
        [ -n "$sess_create" ] && create_i=$(to_int "$sess_create")
        denom=$(( in_i + create_i + read_i ))
        if [ "$denom" -gt 0 ]; then
            cache_pct=$(awk -v r="$read_i" -v d="$denom" 'BEGIN { printf "%d", int(r * 100 / d + 0.5) }')
            [ -n "$cache_seg" ] && cache_seg+=" "
            cache_seg+="${dim}cache:${reset}${green}${cache_pct}%${reset}"
        fi
    fi
    [ -n "$cache_seg" ] && line1+="${sep}${cache_seg}"
fi

# Grok sends no plan-usage line, so auto and always both show a cost that is present.
if [ -n "$cost_usd" ] && [ "$cost_mode" != never ]; then
    line1+="${sep}${white}$(awk -v c="$cost_usd" 'BEGIN { printf "$%.2f", c }')${reset}"
fi

printf '%s' "$line1"
exit 0

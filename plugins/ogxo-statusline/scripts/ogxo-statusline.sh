#!/usr/bin/env bash
# ogxo status line for Claude Code.
#
# Reads the session JSON that Claude Code writes to stdin and prints two lines:
#   1. model │ context use │ directory (git branch, ahead/behind, changes) │
#      session time │ thinking and effort │ output tokens, prompt cache │ cost
#   2. 5-hour and 7-day plan usage, and the spend limit when one is set
# Every value comes from stdin or local git; the script makes no network calls
# and reads no credentials. Line 2 appears only when Claude Code sends
# rate_limits (claude.ai Pro/Max, or a gateway with a spend limit).
#
# Options (add them to the statusLine command in settings.json):
#   --no-git          skip the git branch segment
#   --no-usage        skip the plan usage line
#   --no-cache        skip output tokens and prompt-cache status
#   --cost=MODE       session cost: auto (only without plan usage, the default),
#                     always, or never
#   --basic-colors    16-color ANSI instead of 24-bit color
#   --no-color        plain text (also when NO_COLOR is set)

set -f

show_git=true
show_usage=true
show_cache=true
cost_mode=auto
palette=truecolor
[ -n "${NO_COLOR:-}" ] && palette=none

for arg in "$@"; do
    case "$arg" in
        --no-git) show_git=false ;;
        --no-usage) show_usage=false ;;
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
        blue='\033[38;2;0;153;255m'
        orange='\033[38;2;255;176;85m'
        green='\033[38;2;0;175;80m'
        cyan='\033[38;2;86;182;194m'
        red='\033[38;2;255;85;85m'
        yellow='\033[38;2;230;200;0m'
        white='\033[38;2;220;220;220m'
        magenta='\033[38;2;180;140;255m'
        dim='\033[2m'
        reset='\033[0m'
        ;;
    basic)
        blue='\033[34m'
        orange='\033[33m'
        green='\033[32m'
        cyan='\033[36m'
        red='\033[31m'
        yellow='\033[93m'
        white='\033[37m'
        magenta='\033[35m'
        dim='\033[2m'
        reset='\033[0m'
        ;;
    *)
        blue='' orange='' green='' cyan='' red='' yellow='' white='' magenta='' dim='' reset=''
        ;;
esac

sep=" ${dim}│${reset} "

# ── Read every field in one jq call ─────────────────────
# Fields are joined with the ASCII unit separator: tabs would collapse empty
# fields under `read`, and a missing field must stay an empty slot.
IFS=$'\x1f' read -r model size used_pct in_tok cache_create cache_read out_tok \
    cwd duration_ms thinking effort worktree cost_usd \
    cache_warm cache_observed cache_expires hit_ratio \
    h5_pct h5_reset d7_pct d7_reset sp_pct sp_reset <<<"$(printf '%s' "$input" | jq -r '
    [ .model.display_name,
      .context_window.context_window_size,
      .context_window.used_percentage,
      .context_window.current_usage.input_tokens,
      .context_window.current_usage.cache_creation_input_tokens,
      .context_window.current_usage.cache_read_input_tokens,
      .context_window.current_usage.output_tokens,
      (.workspace.current_dir // .cwd),
      .cost.total_duration_ms,
      .thinking.enabled,
      .effort.level,
      .workspace.git_worktree,
      .cost.total_cost_usd,
      .prompt_cache.warm,
      .prompt_cache.caching_observed,
      .prompt_cache.expires_at,
      .prompt_cache.hit_ratio,
      .rate_limits.five_hour.used_percentage,
      .rate_limits.five_hour.resets_at,
      .rate_limits.seven_day.used_percentage,
      .rate_limits.seven_day.resets_at,
      .rate_limits.spend_limit.used_percentage,
      .rate_limits.spend_limit.resets_at
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
    if [ "$pct" -ge 90 ]; then printf '%b' "$red"
    elif [ "$pct" -ge 70 ]; then printf '%b' "$yellow"
    elif [ "$pct" -ge 50 ]; then printf '%b' "$orange"
    else printf '%b' "$green"
    fi
}

build_bar() {
    local pct=$1 width=$2 i
    [ "$pct" -lt 0 ] && pct=0
    [ "$pct" -gt 100 ] && pct=100
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local filled_str="" empty_str=""
    for ((i = 0; i < filled; i++)); do filled_str+="●"; done
    for ((i = 0; i < empty; i++)); do empty_str+="○"; done
    printf '%b' "$(color_for_pct "$pct")${filled_str}${dim}${empty_str}${reset}"
}

# format_epoch <epoch seconds> <time|date>: local "3:45pm" or "sep 30".
format_epoch() {
    local epoch=$1 fmt out
    [ "$2" = "time" ] && fmt="%l:%M%p" || fmt="%b %e"
    out=$(date -r "$epoch" +"$fmt" 2>/dev/null || date -d "@$epoch" +"$fmt" 2>/dev/null)
    printf '%s' "$out" | tr -s ' ' | sed 's/^ //' | tr '[:upper:]' '[:lower:]'
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

now=$(date +%s)

# ── Line 1: session ─────────────────────────────────────
[ -n "$model" ] || model="Claude"
[ -n "$cwd" ] || cwd=$(pwd)
current=$(( ${in_tok:-0} + ${cache_create:-0} + ${cache_read:-0} ))

line1="${blue}${model}${reset}"

if [ -n "$used_pct" ]; then
    pct=$(to_int "$used_pct")
    line1+="${sep}◔ $(color_for_pct "$pct")${pct}%${reset}"
    if [ -n "$size" ] && [ "$size" -gt 0 ]; then
        line1+=" ${dim}($(format_tokens "$current")/$(format_tokens "$size"))${reset}"
    fi
fi

line1+="${sep}${cyan}$(basename "$cwd")${reset}"
[ -n "$worktree" ] && line1+=" ${dim}[wt:${worktree}]${reset}"

if $show_git; then
    # One git call: branch, upstream ahead/behind, and changed entries.
    # --no-optional-locks keeps it from contending with git commands Claude runs.
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

if [ "$thinking" = "true" ]; then
    line1+="${sep}${magenta}◐ thinking${reset}"
elif [ "$thinking" = "false" ]; then
    line1+="${sep}${dim}◑ thinking${reset}"
fi
[ -n "$effort" ] && line1+=" ${dim}effort:${reset}${white}${effort}${reset}"

if $show_cache; then
    cache_seg=""
    [ -n "$out_tok" ] && cache_seg+="${dim}out:${reset}${white}$(format_tokens "$out_tok")${reset}"
    if [ -n "$hit_ratio" ]; then
        [ -n "$cache_seg" ] && cache_seg+=" "
        cache_seg+="${dim}cache:${reset}${green}$(to_int "$(awk -v r="$hit_ratio" 'BEGIN { print r * 100 }')")%${reset}"
    fi
    # A cold cache makes the next message re-process the whole prompt, so say
    # when it has gone cold, and count down its last ten minutes.
    if [ "$cache_warm" = "true" ] && [ -n "$cache_expires" ]; then
        left=$(( cache_expires - now ))
        if [ "$left" -le 0 ]; then
            cache_seg+=" ${red}cold${reset}"
        elif [ "$left" -le 600 ]; then
            cache_seg+=" ${yellow}cold in $(format_duration "$left")${reset}"
        fi
    elif [ "$cache_warm" = "false" ] && [ "$cache_observed" = "true" ]; then
        cache_seg+=" ${red}cold${reset}"
    fi
    [ -n "$cache_seg" ] && line1+="${sep}${cache_seg}"
fi

has_usage=false
[ -n "$h5_pct$d7_pct$sp_pct" ] && has_usage=true
if [ -n "$cost_usd" ]; then
    if [ "$cost_mode" = always ] || { [ "$cost_mode" = auto ] && ! $has_usage; }; then
        line1+="${sep}${white}$(awk -v c="$cost_usd" 'BEGIN { printf "$%.2f", c }')${reset}"
    fi
fi

# ── Line 2: plan usage ──────────────────────────────────
# window_segment <label> <used %> <resets_at> <time|date>
window_segment() {
    [ -n "$2" ] || return 0
    local pct out
    pct=$(to_int "$2")
    out="${dim}$1${reset} $(build_bar "$pct" 6) $(color_for_pct "$pct")${pct}%${reset}"
    [ -n "$3" ] && out+=" ${dim}⟳${reset}${white}$(format_epoch "$3" "$4")${reset}"
    printf '%s' "$out"
}

rate_line=""
if $show_usage && $has_usage; then
    for segment in \
        "$(window_segment 5h "$h5_pct" "$h5_reset" time)" \
        "$(window_segment 7d "$d7_pct" "$d7_reset" date)" \
        "$(window_segment spend "$sp_pct" "$sp_reset" date)"; do
        [ -n "$segment" ] || continue
        [ -n "$rate_line" ] && rate_line+="$sep"
        rate_line+="$segment"
    done
fi

printf '%b' "$line1"
[ -n "$rate_line" ] && printf '\n%b' "$rate_line"
exit 0

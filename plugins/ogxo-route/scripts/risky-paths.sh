#!/usr/bin/env bash
# Print the paths on stdin that match a risk-path pattern, one per line.
# Built-in patterns match whole path segments (an optional plural or suffix
# is allowed), so "ci" matches src/ci/ but not services/, and "lock" matches
# lock.go but not package-lock.json. Each argument adds a case-insensitive
# extended regex, e.g. from "risky paths" in .claude/ogxo-route.md.
# Documentation files (.md, .mdx, .rst, .txt) are never risky by path.
#   git diff --name-only <range> | risky-paths.sh ['contracts/' ...]
set -uo pipefail

words='auth[a-z]*|login|sessions?|tokens?|crypto[a-z]*|secrets?|permissions?|acls?|migrations?|schemas?|payments?|billing|invoices?|wallets?|balances?|contracts?|locks?|mutex(es)?|queues?|cache|ci|deploy[a-z]*|terraform|helm|k8s|docker[a-z-]*|releases?'
re="(^|/)($words)([^a-z0-9]|$)|\\.sql\$|(^|/)Dockerfile|(^|/)\\.github/workflows/"
for extra in "$@"; do
  [ -n "$extra" ] && re="$re|$extra"
done
grep -viE '\.(md|mdx|rst|txt)$' | grep -iE "$re" || true

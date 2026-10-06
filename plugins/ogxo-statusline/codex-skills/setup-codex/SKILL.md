---
name: setup-codex
description: Configure the native Codex CLI footer with its /statusline picker. Use when setting up or changing model, context, git, token, or rate-limit status items in Codex.
---

# Set up the Codex status line

Codex CLI renders its own footer from an ordered list of built-in items in
`[tui] status_line`. It does not run either ogxo Claude or Grok shell
renderer. This skill uses the native picker, so it needs no copied script,
`jq`, or TOML editor.

1. Explain that this applies to the interactive Codex CLI. Desktop and IDE
   interfaces have their own UI; `codex exec` has no interactive footer.
2. Tell the user to enter `/statusline` in the CLI. An assistant message
   containing that text does not execute the command for them.
3. Recommend this order using the labels present in their picker: model
   with reasoning, context remaining, current directory or project root,
   git branch, rate limits, and token counters. Use only items the picker
   offers; the available set can differ by installed version.
4. The user toggles and reorders items, then confirms. Codex updates the
   footer immediately and persists `tui.status_line` in `config.toml`.
   If they already customized the footer, explain the choices and let
   them keep the ones they want. Do not write their global config as part
   of merely loading this skill.
5. To remove items, reopen `/statusline` and deselect them. To remove the
   whole footer, deselect all items in the picker when that version offers
   it. Do not describe TOML `null` as an editable literal: TOML has no null
   value. If disabling is unavailable, report that version's limitation.

If `/statusline` is unavailable, inspect `codex --version` and
`codex --help` and report the limitation. Do not fall back to a Claude
`statusLine` command or Grok `[ui.status_line]` table.

Codex supplies the selected values. This plugin does not estimate dollar
costs, infer Anthropic cache state, count ogxo-route dispatches, or feed
Claude's live board. Items such as rate limits may be absent until Codex
has account data. A setup response reports these instructions as ready,
not the user's configuration as changed.

Sources: [Codex CLI commands](https://developers.openai.com/codex/cli/slash-commands/)
documents `/statusline` and persistence; [configuration reference](https://developers.openai.com/codex/config-reference/)
documents `tui.status_line` as item identifiers.

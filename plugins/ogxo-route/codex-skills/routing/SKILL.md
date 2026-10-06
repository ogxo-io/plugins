---
name: routing
description: Classify and route scoped Codex implementation, exploration, test, log, browser, and verification work. Use before delegating tasks or choosing to handle a task inline.
---

# Route tasks in Codex

Resolve the plugin root from this loaded skill's path: two directories
above this skill directory. Read `../../skills/routing/SKILL.md` relative
to this skill's directory: it holds the routing rules shared with Claude
Code and Grok Build (when to work inline, the risk triggers and tiers, the
breadth threshold, splitting tickets, verification and escalation, the
hand-off format, and parallel batches). Follow it, with these Codex
substitutions.

## Host differences

- **Step 0.** Read the project's `AGENTS.md` first. Read
  `.codex/ogxo-route.md` when it exists, in addition to
  `.claude/ogxo-route.md`; either may add risky paths and change the
  breadth threshold.
- **Workers.** Use native Codex collaboration tools when available and
  session instructions allow delegation; otherwise apply the same
  procedures in the main session. An `ogxo-route:<name>` worker in the
  shared rules means that procedure from `../worker-procedures/SKILL.md`,
  given to a native worker; it is not a registered agent type. Read that
  skill before dispatch.
- **Models.** The Opus, Sonnet, and Haiku pins, the `model:` parameters,
  and the price comparisons do not apply. Use the inherited session model,
  and override model or effort only when the user or project instructions
  ask and the collaboration tool supports it. The risk tiers still decide
  how a ticket is split and which work gets the risky-task review.
- **Step 3.** Route each task to the native procedure the table names.
  `codex:codex-rescue` does not apply inside Codex. A request naming Grok
  uses grok-build's real bridge when it is installed and authorized, not a
  Codex worker named Grok; if the bridge is unavailable or fails, report it
  and do not substitute another worker. The bridge commands in the shared
  rules assume Claude Code's plugin layout.
- **Reviews.** `ogxo-review:code-review-agent` means ogxo-review's
  code-review-agent skill when it is installed, or a native review worker
  following `agents/code-review-agent.md` from ogxo-review.
- **Step 4.** A retry "one tier up" is a focused retry with the failure
  evidence attached; a second failure returns to the main session.
- **Not available in Codex:** Step 5 (the marked-off state and
  `/ogxo-route:external`), the Grok Build section, Step 6 (advisor),
  `/ogxo-route:handoff`, `/compact`, `run_in_background`, and the live board
  (`/ogxo-route:dashboard` and `dash.sh`). Keep the Batch table in the
  conversation instead.
- **Paths.** Replace `${CLAUDE_PLUGIN_ROOT}` in the shared rules with the
  plugin root's absolute path.
- **Git.** Every dispatch brief says to leave unrelated edits alone and not
  to stage, commit, push, stash, reset, checkout, or restore files. Inspect
  working-tree and staged diffs separately, plus untracked files; an empty
  selected diff means the range or scope needs investigation.

## Telemetry limits

This Codex overlay exports skills and explicitly disables the Claude hooks
with an empty inline hook configuration in `.codex-plugin/plugin.json`. It has no session-start
anchor, Claude model-cost/quota advisor, permission log, dispatch log,
alerts, external-state command, handoff command, stats command, or live
dashboard. Do not run the Claude commands/scripts to present Codex usage.
Keep worker results and a small task/files/checks table in the conversation.
For native account/session data use Codex `/status`; for its CLI footer use
`ogxo-statusline`'s `setup-codex` skill when installed.

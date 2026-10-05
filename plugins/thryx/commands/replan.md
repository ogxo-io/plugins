---
description: Replan a ThryX project's cycles from every open ticket (Triage, Backlog, Ready, and the planned cycles) and propose the result before writing anything
argument-hint: "[PROJECT_KEY] [what to focus on]"
---

Replan the cycles of a ThryX project. Load the `thryx:product-management`
skill and the `thryx:thryx` skill, then read
`${CLAUDE_PLUGIN_ROOT}/skills/product-management/references/replan.md` and
follow it from step 1.

Use the project key in `$ARGUMENTS` if it names one. Otherwise use a
`ThryX project: KEY` line in `CLAUDE.md` or `AGENTS.md`, or else the key in
the branch name. Ask only when none of those names one. Resolve the
workspace as the thryx skill says. Anything else in `$ARGUMENTS` is a focus
for the replan (for example "only Triage" or "through the December
promise"), so apply it within the reference's steps.

The result is a proposal. Make no writes until the person answers.

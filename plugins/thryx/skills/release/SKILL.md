---
name: release
description: Prepare, ship, or check a ThryX release from its git tag - reconcile the tag with the tracker, assign the release's tickets, write its notes and promises, then stop for approval before shipping and verify what shipped. Use for "prepare the v1.4 release", "ship v1.4", or "check the last release".
---

# Prepare and ship a ThryX release

Read the sibling `../product-management/SKILL.md` and `../thryx/SKILL.md`,
then `../product-management/references/release.md` and
`../product-management/references/roadmap.md`, resolving paths relative
to this SKILL.md's directory. Follow the release reference from step 1.

Use the project key in the user's request. Otherwise use a `ThryX project:
KEY` line in `AGENTS.md` or `CLAUDE.md`, or the key in the branch name. Ask
only when none names one. Resolve the workspace as the thryx skill says.
Take the version from the request; without one, use the newest tag that
has no shipped release in ThryX, and say which you picked. Apply any
remaining request text as the focus (for example "notes only" or "check
what shipped").

A request to prepare the release covers the preparation writes in steps 1
to 3. Shipping is a separate answer: stop with the finished draft and ask,
unless the user already told you to ship. Completing the cycle and posting
an announcement each need their own answer too.

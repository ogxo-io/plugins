---
name: release
description: "Prepare a version bump and changelog, verify the release, and publish its tag and GitHub release when authorized."
---

# Release

1. Read repository release conventions and instructions. Run `git status --short`, `git branch --show-current`, and `git describe --tags --abbrev=0` at runtime. Verify the release branch and a clean tree; report unexpected local changes and pause before mixing them into a release.
2. Read the actual commits and diff since the last tag. If there is no tag, inspect project history and version files for a first release. If the selected diff/history is empty, report the empty scope and stop. Determine a SemVer candidate from breaking changes, features, and fixes, then confirm the version if the user has not specified it.
3. Read `../../skills/changelog-generator/SKILL.md` and `../../skills/release-notes/SKILL.md`; draft the changelog and notes from the selected history. Update the project's version sources and lockfiles using its documented tooling. For npm, use `npm version <version> --no-git-tag-version` so version preparation does not implicitly commit or tag.
4. Run release tests/build checks and inspect the resulting diff. Present the concrete version, changelog, notes, and file changes. Ask the user to stage the reviewed release files; do not stage yourself.
5. Inspect `git diff --cached` and verify it contains only the intended release files. Commit when authorized using `git commit` with signing/hooks intact and no attribution, then create the annotated release tag using the project's naming convention. Confirm destructive/irreversible publication decisions if not already authorized.
6. Push the approved release commit and only its tag, then use `gh release create <tag> --title <title> --notes-file <file>` with the exact approved notes. Check each result, stop after a failure, and return the release URL or the concrete manual publication instructions if GitHub tooling is unavailable.

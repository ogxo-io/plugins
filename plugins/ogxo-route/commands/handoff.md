---
description: Save a short handoff note for this session (goal, decisions, state, next step) so a fresh or compacted session continues cheaply, or read it back with resume
argument-hint: "[resume | latest]"
allowed-tools: Bash(CLAUDE_PLUGIN_DATA=*)
---

A long session is expensive because every message re-reads all of it. A
handoff note moves what matters into a small file so you can start fresh
(or run `/compact`) and lose nothing that you need.

If the arguments are `resume` (or `latest`), read the note back and continue:

```bash
CLAUDE_PLUGIN_DATA="${CLAUDE_PLUGIN_DATA}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/handoff.sh" show
```

With `latest`, run the script with `latest` instead and read the file it
prints. Then say the goal and the next step in two lines, check the state
the note describes against `git status` and `git log` (the note can be
older than the working tree), treat its decisions as settled unless the
code or the user contradicts them, and continue from the next step. Stop
there; the rest of this file is for writing a note.

Otherwise, write the note. First collect the facts in one call, not from
memory:

```bash
CLAUDE_PLUGIN_DATA="${CLAUDE_PLUGIN_DATA}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/handoff.sh" facts
```

Then write the note, at most about 60 lines, with these sections and
nothing else:

- **Goal:** what this work is for, in a sentence or two.
- **Decisions:** what was settled and why, one line each. Settled means the
  next session should not reopen it.
- **State:** what is done, what is half done, what has not started.
  Uncommitted changes, branches and worktrees by name, and whether the tests
  last passed. Use paths and `file:line`, not pasted code.
- **Open:** questions only the user can answer, and risks you could not
  rule out.
- **Next step:** the exact first action, concrete enough to start without
  asking.
- **Pointers:** ticket keys, documents, handoff files of workers still to
  continue, and the commands that re-run the checks.

Leave out what git or the tracker already says (diffs, ticket text), and
never put tokens, passwords, or other secrets in it. Store it by piping it
to the script; the script picks the file for this repository and branch:

```bash
CLAUDE_PLUGIN_DATA="${CLAUDE_PLUGIN_DATA}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/handoff.sh" write <<'NOTE'
<the note>
NOTE
```

Show the script's output. Then tell the user the two ways to continue: run
`/compact` and keep going, or start a new session in the same directory and
run `/ogxo-route:handoff resume`. Do not start the next piece of work in
this session.

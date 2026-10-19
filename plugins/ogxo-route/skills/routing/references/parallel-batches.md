# Parallel batches

Step 8 of the routing skill. `<plugin-root>` and `<plugin-data>` are
ogxo-route's own folder and data folder, which the routing skill gives;
`<data>` and `<path>` in a grok bridge command are grok-build's, from
`grok-bridge.md` in this folder.

**Project policy first.** Before choosing a mode, read the project's
`CLAUDE.md`, `AGENTS.md` and `.claude/ogxo-route.md` for a parallel-work or
worktree rule (for example "one worktree per ticket"). A rule there wins
over the defaults below and needs no extra confirmation; name it in the
Batch table's mode column.

Before dispatching more than one implementation task at a time, write a
**Batch table** in the conversation, one row per task: task, writer (grok,
codex, implementer), files it may edit, files that are off-limits because
another task owns them, mode (shared or isolated), and anything created for
it outside the repository files (a build directory, test database,
container, or port), so it can be removed when the task is done.

Dependency caches are shared by default: package stores and registries
(`GOCACHE`, the pnpm store, the uv cache, `GRADLE_USER_HOME`, Cargo's
registry) and a compile cache such as sccache or ccache. Honour the
machine's and project's existing settings for them and do not override them
in briefs: rebuilding every dependency per task multiplies build time and
disk use. A build output directory is another matter. In the shared tree
there is one checkout and one output, so nothing changes. In an isolated
batch, give each worktree its own output when the toolchain names its
artefacts by package rather than by source tree, as Cargo does: the
binaries it copies up into `target/debug/` are named by crate alone, so
worktrees sharing one `target-dir` (a machine-wide one included) overwrite
each other's binaries, a test run can execute another tree's build, and
their builds queue on one lock. For Cargo, set `CARGO_TARGET_DIR` to a
`target` folder inside the worktree and keep dependencies coming from the
shared cache with sccache and `CARGO_INCREMENTAL=0` (sccache does not cache
incremental builds, and incremental state is most of a target's size). Also
give a task its own output when it builds with different flags or features,
or when a long-running process (a watcher or dev server) holds the shared
build lock. List every per-task output in the Batch table. The project's
own `CLAUDE.md` or build docs take precedence.

Tasks that append to the same file (a test file, changelog, route or
registry table, fixture list) always conflict when merged. Tell each worker
to add its entries in one contiguous block headed by the task id, not
interleaved with others.

Targeted tests miss what a task breaks in another area: a shared prompt,
catalog, or status rule that other areas' tests depend on. Once per batch,
after its tasks are combined and before the user pushes, run the full
suite through `ogxo-route:test-runner`; the per-task runs do not replace it.

**Live board.** Before the first batch in a session, offer the user
`/ogxo-route:dashboard` once: a local HTML page, updated by hooks, showing
this session's agents, their tool calls, and the batch. When the board is
on, record the Batch table on it and use each row's task name in that
task's dispatch description, so the board can link rows to agents:

```bash
CLAUDE_PLUGIN_DATA="<plugin-data>" bash "<plugin-root>/scripts/dash.sh" batch <<'JSON'
[{"task": "<task>", "writer": "<grok|codex|implementer>", "files": ["<path>"], "mode": "shared"}]
JSON
```

For an isolated task, set `"mode": "isolated"` and add `"worktree": ".claude/worktrees/<task>"`.

When the board is off, the script prints a note and writes nothing.

## Shared tree (default)

All writers edit the user's checkout. This is cheap and needs no setup.

- Run tasks in parallel only when their file sets do not overlap. A task that shares a file with a running task waits for it.
- At most two concurrent writers, and this cap is hard. When the user asks for more speed or more workers, the answer is an isolated batch, not a third writer in the shared tree. grok's run state also contends beyond two runs.
- Watchers, hot reloaders, and dev servers that compile, apply, or generate from the working tree act on half-finished work: they can apply a draft migration (sqlx, Django, Prisma, goose, Alembic), run codegen or seeds, sync a schema, or rebuild bundles. On a shared database the damage outlives the task. Run tasks that touch migrations, schema, or generated artefacts in an isolated batch. Otherwise, before trusting E2E or integration results, check what was actually applied (the migration version table or checksums, with the project's own command).
- Every worker brief lists the files it may edit and the off-limits files, says not to run git add, commit, stash, checkout, reset, or restore, and says to leave changes it did not make alone and report them.
- A worker's own tests see the other runs' unfinished edits. Before committing a task, re-run typecheck, unit tests, and the relevant e2e specs on the combined tree.
- Commit each task by explicit path (`git add -- <its files>`), and only when the user asks. If two tasks touched the same file, split the hunks so each commit carries only its task.

## Isolated batch (opt-in)

One git worktree per task, merged back one at a time. Suggest it when the
user is editing the main checkout while the batch runs, when more than two
writers should run at once, when tasks that overlap in files must still run
in parallel, when a task touches migrations, schema, or generated artefacts
while a watcher runs on the main checkout, or when the user wants the main
tree untouched until a task is done. Ask before using it, unless the
project's policy (above) already requires it or the user asked for more
than two writers.

1. Check free disk first: `df -Pk .`. Below 20 GiB free (20971520 in its Available column), stop and tell the user instead of creating the worktree (`.claude/ogxo-route.md` can set another threshold). One cold dependency build of a large project can take about 10 GiB; 20 GiB leaves room for one more build and test artefacts.
2. Create the worktree from the current commit, so unpushed commits are included:
   `git worktree add .claude/worktrees/<task> -b task/<task> HEAD`.
   Uncommitted changes in the main checkout are not carried over; if the task depends on them, say so and stay in the shared tree. Keep worktrees under `.claude/worktrees/`, inside the project, and put that directory in `.gitignore`.
3. Set up the worktree: dependencies (install, or symlink `node_modules`), and gitignored files the build needs (a `.worktreeinclude` file copies them for worktrees Claude Code creates; copy them yourself for this one). Keep the shared dependency caches, and give the worktree its own build output where the toolchain needs one (above). Worktrees isolate files only: test databases, ports, and containers are still shared, so keep per-task test databases and distinct ports, and list them in the Batch table.
4. Point the writer at it: grok, from the worktree as the working directory (a plain `cd <worktree>` as its own command, then `CLAUDE_PLUGIN_DATA=<data> node <path>/grok-bridge.mjs run --background --write --fresh ...`); codex `codex exec -C <worktree> ...` or `codex:codex-rescue` with the path in its prompt; `ogxo-route:implementer` with the absolute worktree path in its brief and the instruction to edit only under it.
5. Before a fix round in an existing worktree, run `git -C <worktree> status --porcelain` and stop on any file outside the task's scope. If the main branch has since changed files the task touches, recreate the worktree from the current `HEAD` and apply the task's diff as a patch (`git diff <base>..task/<task> > <patch>`, then `git -C <new-worktree> apply --3way <patch>`) rather than rebasing a long way.
6. When the task is done: run tests and `ogxo-route:verifier` inside the worktree, commit the task on its throwaway branch (`git -C <worktree> add -A && git -C <worktree> commit -m "<task>"`), show the user `git diff HEAD...task/<task>`, and only after the user approves run `git merge --squash task/<task>` in the main checkout. That stages the task for the user to review and commit. `git merge --squash` suits a task branch with several commits; `git cherry-pick -n <sha>` brings over a single commit the same way. Merge tasks one at a time and re-run the combined-tree checks after each.
7. Clean up: `git worktree remove .claude/worktrees/<task>` and `git branch -D task/<task>`. Removing the worktree deletes its directory, ignored files included, but nothing created outside it: also remove every build directory, test database, and container the Batch table lists for the task.

Conflicts do not go away in an isolated batch; they move to merge time. A
task that overlaps with one already merged is rebased onto the main branch
(`git -C <worktree> rebase <main-branch>`) and re-tested before its merge.

Some conflicts merge silently. When two tasks bump the same version line
the same way, or change the same digest or generated number, git sees
identical edits and keeps one: the result is one bump where two were meant.
After each merge, recompute versions, digests, and generated files on the
combined tree instead of trusting the merged values.

For a conflict in a file several tasks append to, keep one side whole and
re-add the other: take the main branch's file and append the task's block,
or take the task's file and re-apply the main branch's changes since the
worktree's base. Then check that no entry was dropped or duplicated by
comparing sorted test names before and after, extracted with the project's
test declaration pattern (for example `#[test]` then `fn name`, `it(`/`test(`,
`def test_`, `func Test`); `sort | uniq -d` shows duplicates, `comm -3`
shows what is missing.

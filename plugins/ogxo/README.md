# ogxo

The ogxo plugin set in one install for Claude Code. Its Claude package has no skills, agents, or hooks of its own; installing it installs each plugin below as a dependency.

```bash
claude plugin marketplace add ogxo-io/plugins
claude plugin install ogxo@ogxo
```

## Codex

```bash
codex plugin marketplace add ogxo-io/plugins
codex plugin add ogxo@ogxo
```

Start a new Codex session and ask to install the ogxo collection. The Codex
package exports `ogxo:setup`, which installs each member through `codex plugin
add`; it does not rely on Claude's dependency installation. You can also
install individual plugins directly. ThryX and formatting remain optional.
Review and trust installed hook definitions before relying on the guards.
Use `ogxo-statusline:setup-codex` for Codex's native terminal status line.

## What it installs

- `ogxo-review`: multi-agent code review and security checks
- `ogxo-git`: commit messages, PR descriptions, review threads, releases
- `ogxo-debug`: live browser debugging, layout debugging, Playwright tests
- `ogxo-decide`: war-room deliberation, PRDs, task prompts, architecture advice, diagrams
- `ogxo-design`: color-system audit and redesign
- `ogxo-guards`: hooks that reject staging secret files, editing lock files and vendored paths, and oversized writes
- `ogxo-specialists`: log analysis, legacy-code mapping, performance, and migration subagents
- `ogxo-statusline`: status line for Claude Code and Grok Build; turn it on with `/ogxo-statusline:setup`
- `ogxo-route`: worker routing; Codex uses its native worker tools without Claude cost telemetry

Two plugins are left out on purpose. Install them by name when you want them:

- `thryx`: needs a ThryX account, and one MCP server per workspace, added with `/thryx:connect`
- `ogxo-format`: reformats every file Claude edits

## Updating and removing

When a plugin is added to the set, this plugin's version goes up, and updating it (or marketplace auto-update) installs the new plugin.

Uninstalling `ogxo` leaves the plugins it installed. Run `claude plugin prune` afterwards to remove the ones nothing else needs.

Disabling one of the plugins above disables `ogxo` too, since it depends on all of them. That has no other effect: `ogxo` itself contains nothing.

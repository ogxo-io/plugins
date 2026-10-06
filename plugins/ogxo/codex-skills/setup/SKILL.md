---
name: setup
description: Install the ogxo plugin collection in Codex, or select individual ogxo plugins. Use when the user asks to set up the ogxo bundle in Codex.
---

The Codex `ogxo` package provides this setup workflow. Installing it alone does
not install the collection through Claude's dependency mechanism.

When asked to install the collection, use the available shell tool to run
`codex plugin marketplace list`. If the `ogxo` marketplace is missing, run
`codex plugin marketplace add ogxo-io/plugins`. Then install these plugins with
`codex plugin add <name>@ogxo`, one command per plugin:

- ogxo-review
- ogxo-git
- ogxo-debug
- ogxo-decide
- ogxo-design
- ogxo-guards
- ogxo-specialists
- ogxo-statusline
- ogxo-route

If the user names a subset, install that subset. Keep `thryx` and `ogxo-format`
optional: ThryX needs a workspace connection; format hooks rewrite edited
files. Include either when the user requests it.

Inspect command output. Report failures precisely rather than claiming the
collection installed. A sandbox permission failure needs the host's normal
approval flow; do not work around it by editing the user's configuration.
Installing plugins does not activate their skills in this already-running
session. Tell the user to start a new session after installation, review and
trust the guards' hook definitions, and invoke `ogxo-statusline:setup-codex`
if they want the native Codex terminal status line. Routing uses Codex worker
tools; the Claude/Grok live cost board is not implemented for Codex.

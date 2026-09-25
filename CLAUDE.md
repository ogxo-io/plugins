# CLAUDE.md — ogxo-io/plugins

This repository is the **ogxo plugin marketplace**: mostly a catalog. It holds
`.claude-plugin/marketplace.json` and this documentation. Plugins backed by a product
stay in the product repository, referenced from here by Git URL + path + tag;
content-only plugins (and thryx) are vendored under `plugins/` (see
Conventions below).

Marketplace name: `ogxo` → plugins install as `<plugin>@ogxo`.

## Status

- The catalog has ten entries, all vendored under `plugins/`: **thryx**, and
  nine content-only plugins — **ogxo-review**, **ogxo-git** (0.2.0),
  **ogxo-debug**, **ogxo-decide** (0.3.0), **ogxo-design**, **ogxo-guards**,
  **ogxo-format**, **ogxo-specialists**, **ogxo-statusline** (0.2.0). The hook
  plugins require `jq`; each hook prints a notice and does nothing when it is
  missing. ogxo-statusline installs through a setup skill because the status
  line setting lives in the user's own config: setup copies the script to
  `~/.claude/` and edits settings.json; setup-grok copies the script to the
  Grok home and writes `[ui.status_line]` in config.toml.
  This repo is the source of truth for them. The user decides when to commit; never `git add` or commit on your
  own.

## Conventions (decided with the user)

- **Content-only plugins are vendored here.** A plugin that is only skills,
  agents, commands, or hooks — no MCP server or binary it has to stay in sync
  with — lives at `plugins/<plugin>` and is referenced as `"./plugins/<plugin>"`.
  Bump its `version` in both `plugin.json` and the catalog entry on every
  change. Paths inside plugin content use `${CLAUDE_PLUGIN_ROOT}` (substituted
  in skill and agent bodies); never `~/.claude/...`. Plugin agents and
  commands are addressed as `<plugin>:<name>` (e.g. `ogxo-review:security-auditor`,
  `/ogxo-review:full-review`). Generic plugins take the `ogxo-` prefix so their
  `<plugin>:` namespace can't collide with other marketplaces' plugins or read
  like a built-in command; product plugins keep the product name (`thryx`).
- **Product-backed plugins: source stays with the product.** A plugin lives at
  `ogxo-io/<product>/plugins/<plugin>`; this repo only points at it.
  Reason: the plugin's `.mcp.json` mirrors the product's tool surface and
  env vars, so one PR changes both and the product's CI installs the plugin from the local path (`grok plugin
  install <path>` accepts one; `claude plugin install` does not — see below)
  as a gate.
- **Pin every entry to a release tag** produced by `claude plugin tag` in the
  product repo (format `<plugin>--v<version>`, e.g. `<plugin>--v0.1.0`), and record
  the commit `sha`. Update the pin when the product releases; never point at a
  branch.
- **No second marketplace inside a product repo.** One public name per plugin
  (`<plugin>@ogxo`). `claude plugin install` takes a `plugin@marketplace` name
  resolved from a configured marketplace, never a filesystem path — there is
  no path form to fall back on. For a quick, session-scoped try, use
  `claude --plugin-dir <path>` (untested here; see `claude --help`). To test
  a real install, point a throwaway marketplace at the plugin with a
  *relative* source (an absolute `source` is rejected):

  ```bash
  mkdir -p /tmp/ogxo-local/.claude-plugin
  ln -s /path/to/<product>/plugins/<plugin> /tmp/ogxo-local/<plugin>
  cat > /tmp/ogxo-local/.claude-plugin/marketplace.json <<'JSON'
  { "name": "ogxo-local", "owner": { "name": "ogxo", "url": "https://github.com/ogxo-io" },
    "plugins": [ { "name": "<plugin>", "version": "0.1.0", "source": "./<plugin>" } ] }
  JSON
  claude plugin marketplace add /tmp/ogxo-local
  claude plugin install <plugin>@ogxo-local
  ```
- **Exception, thryx: vendored here.** `plugins/thryx` lives in this repo,
  referenced as `"./plugins/thryx"`. Thryx's source is not public, so
  there is no product repo to pin, and the plugin is five files against a
  stable hosted URL, so co-location would buy little. Every other
  product-backed plugin keeps its source with the product. Revisit if the
  thryx skill starts drifting from the server's tool surface.
- Same plugin tree serves Claude Code and Grok Build (`grok plugin`, identical
  format) and Codex when the plugin also ships a `.codex-plugin/` manifest.

## Entry template (shape verified against Anthropic's own catalog)

For a plugin in a product repo:

```json
{
  "name": "<plugin>",
  "description": "<one sentence on what the plugin does>",
  "version": "0.1.0",
  "author": { "name": "ogxo", "url": "https://github.com/ogxo-io" },
  "homepage": "https://github.com/ogxo-io/<product>",
  "category": "development",
  "keywords": ["mcp"],
  "source": {
    "source": "git-subdir",
    "url": "https://github.com/ogxo-io/<product>.git",
    "path": "plugins/<plugin>",
    "ref": "<plugin>--v0.1.0",
    "sha": "<commit sha of that tag>"
  }
}
```

The `git-subdir` form is what a plugin living in a subdirectory of another
repo needs; `{"source": "url", "url": …, "sha": …}` is for a repo that is the
plugin. Relative `"./plugins/x"` strings are for a plugin vendored into the
marketplace repo — the exception, not the rule; see the thryx bullet above.

## How to work here

```bash
claude plugin validate .                       # validates marketplace.json
claude plugin marketplace add .                # local test, from the repo root
claude plugin install thryx@ogxo
claude plugin marketplace update ogxo          # after editing the catalog
```

For a new entry: add the object to `plugins`, run `claude plugin validate .`,
then a real `claude plugin marketplace add` + `install` from a clean machine
or a temp `HOME` before the user commits.

## Safety claims in distribution copy need a citation

Distribution-facing copy has asserted safety properties the product
doesn't have: a false "worktree scoped to an allowlist of paths" (the
allowlist is detective, not preventive — the write is never blocked), a
false "an API token alone never authorizes a destructive change" (the
confirmation flag is set by the same token-holder), and a true "private
notes never cross an API token" asserted with no evidence until someone
checked. All three originated in plan-authoring, not implementation.

The rule: any sentence in distribution-facing copy — a manifest
`description`/`longDescription`, a README, or a SKILL.md — that claims a
class of action *cannot happen*, *is prevented*, *is scoped*, *requires
authorization*, or *is protected* must carry a `file:line` citation to the
source that establishes it at the time it's written, or be rewritten to
state only the observed mechanism. Run this at plan-authoring time, not as
a review backstop.

```bash
grep -rnE '\b(never|cannot|can.t|prevent|enforce|protect|scoped|isolat|sandbox|boundar|requires? .*authoriz)' plugins --include='*.md' --include='plugin.json'
```

It's deliberately noisy, and spans both plugin trees — this repo's
vendored `plugins/thryx` and any plugin tree in a product repo. When this
check was adopted against v0.1.0, the large majority of its hits were
correct copy: disclaimers ("does not sandbox the worker", "detective, not
preventive", "the write itself is never blocked") and packaging facts
("cannot ship the Go binary"), not overclaims. Disclaimers are the
opposite failure mode and must never be "fixed" into a stronger claim; the
job here is to sort hits, not delete them. Don't record a hit count next
to this: it moves every time any distribution-facing sentence changes —
just run the command and sort what it returns.

Worked example of the right remedy: "private notes never cross an API
token" survived the check because someone made it citable, then rewrote
the copy itself to carry the mechanism — the shipped sentence now reads
that the notes endpoint requires a signed-in session while MCP credentials
are a separate token type that cannot satisfy it, backed by a citation to
the Thryx server's auth extractors. When a flagged sentence turns out to
be true, the fix is to go find the evidence, cite it, and let the copy
state the mechanism — never to weaken the claim instead.

## Rules

- Never add attribution trailers (`Co-Authored-By`, `Claude-Session`) to commits.
- Files end with exactly one newline.
- Do not invent schema fields; the catalog entries above were checked against
  `~/.claude/plugins/marketplaces/claude-plugins-official/.claude-plugin/marketplace.json`.

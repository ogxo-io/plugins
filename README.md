# ogxo plugins

Marketplace for ogxo tools in Claude Code, Grok Build, and Codex.

```bash
claude plugin marketplace add ogxo-io/plugins
claude plugin install thryx@ogxo
claude plugin install ogxo-review@ogxo
claude plugin install ogxo-git@ogxo
claude plugin install ogxo-debug@ogxo
claude plugin install ogxo-decide@ogxo
claude plugin install ogxo-design@ogxo
claude plugin install ogxo-guards@ogxo
claude plugin install ogxo-format@ogxo
claude plugin install ogxo-specialists@ogxo
```

| Plugin | What it is | Status |
|---|---|---|
| `thryx` | Hosted Thryx MCP server, vendored in this repo (`plugins/thryx`): issues, projects, cycles, milestones, and documents in your Thryx workspace. | 0.1.0 |
| `ogxo-review` | Multi-agent code review: `/ogxo-review:full-review` cross-correlates reviewers and filters false positives; `/ogxo-review:code-review-git` posts line-level findings as a GitHub PR review. Bundles the code-review-agent, security-auditor, code-metrics-analyst, and dependency-auditor agents; `/ogxo-review:security-check` for a focused security pass. | 0.2.0 |
| `ogxo-git` | Conventional Commit messages, PR titles/descriptions with template detection, resolving PR review threads (its workflow instructs it to present its analysis and wait for approval before replying or resolving), `/ogxo-git:catchup` to restore branch context, plus release, quick-fix, and ship-feature workflows and changelog/release-notes skills. | 0.2.0 |
| `ogxo-debug` | `live-debug`: reproduce a web-app bug in the browser, read console and network errors, fix, and verify in the page; `css-alignment-debug` injects temporary outline overlays and reads a screenshot to find stubborn layout bugs. Also `browser-testing` for Playwright test scripts. | 0.3.0 |
| `ogxo-decide` | `war-room`: multi-persona deliberation for hard-to-reverse decisions — game-theory lenses, red-team pass, a portfolio of options rather than a single winner; `prd-create` (PRDs, optionally saved to Thryx), `task-architect`, and the architecture-advisor agent. Also `diagram-generator` for Mermaid diagrams. | 0.3.0 |
| `ogxo-design` | `recolor`: audit an app's colors and implement an accessible, token-based color system, with contrast ratios computed by a bundled script. | 0.1.0 |
| `ogxo-guards` | Hooks that reject a `git add` naming .env/credentials/.secret/.pem files, Edit/Write calls on lock files and node_modules/vendor/.git paths, and single writes over 1,048,576 characters. Pattern-based; see its README for what each does not catch. Requires `jq`. | 0.1.0 |
| `ogxo-format` | Hooks that format each edited file with prettier, gofmt, rustfmt, or black when found, report trailing whitespace back to Claude, and check YAML syntax. Opt-in: auto-format rewrites whole files. Requires `jq`. | 0.1.0 |
| `ogxo-specialists` | Subagents that take a noisy job and return one structured report: `log-analyst` (logs → root cause), `codebase-archaeologist` (map a legacy system), `performance-optimizer` (measure, fix by impact, re-measure), `migration-specialist` (breaking changes, phased plan with rollback points). | 0.1.0 |

Plugins backed by a product (an MCP server or binary) pin to a release tag and
commit sha in that product's repository. Content-only plugins — skills, agents,
and commands with no product behind them — are vendored here under `plugins/`.

## License

MIT — see [LICENSE](LICENSE). Each vendored plugin ships its own copy.

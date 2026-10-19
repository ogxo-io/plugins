# Running under Grok Build

Grok Build loads this plugin, its agents, and its hooks, but it runs them
differently, as observed with Grok 1.0.46:

- Workers run on the session's model. Grok does not read the `model:` line
  in the agent files, so `scout` or `test-runner` cost what the main session
  costs per token. In that setup `spawn_subagent` offers no `model`
  argument either. Routing still pays off through scope: a worker starts
  with a small context, so each of its calls re-reads less than the main
  session would. Keep dispatching the same way; the live board shows what
  each worker cost, from Grok's own totals.
- A user-level `[subagents.models]` entry in Grok's `config.toml` does send
  an agent to another model (`"ogxo-route:test-runner" = "<model>"`); a
  project-level one had no effect in a test. `grok-4.7-build-fast` is not
  the cheap tier it sounds like: on the same task it cost about 1.5 times
  what `grok-4.7-build` did. Compare models on the board before pinning one.
- Do not route to grok's bridge from inside Grok; the session is already
  Grok. There is no advisor, so the routing skill's Step 6 does not apply.
- Grok ignores what a SessionStart hook prints, so the routing summary
  does not appear at session start. Load the routing skill before dispatching.

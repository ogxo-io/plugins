---
name: live-debug
description: Debug running web apps by driving browser, reading console and network errors, iteratively fixing code. Use when the user reports a runtime symptom in a web app (broken layout, clicks that do nothing, JS or hydration errors, failing API calls) or wants to confirm a fix in the browser. For writing E2E test suites use ogxo-debug:browser-testing.
paths: ["**/*.{html,css,js,jsx,ts,tsx,vue,svelte,astro}", "**/package.json"]
---

# Live Debug Skill

## Overview

Drive a real browser, read what's actually happening in it, identify the root cause of a bug, fix it in the source code, and verify the fix — all in a tight token-cheap loop. This skill is for *debugging running apps*, not for writing test suites.

## When to Use This Skill

**Use it when the user reports a runtime symptom in a web app:**
- Visual bugs: layout broken, element missing, wrong styling, dark mode issues
- Behavioral bugs: clicks do nothing, forms don't submit, state desyncs
- Runtime errors: blank page, JS exceptions, hydration mismatches
- Network bugs: API calls failing, 4xx/5xx responses, CORS, missing assets
- Verification: "did my fix actually work?"

**Do NOT use this skill for:**
- Writing E2E test suites → use the **ogxo-debug:browser-testing** skill instead
- Performance profiling alone → use Chrome DevTools MCP standalone
- Backend-only bugs with no UI surface → use logs + curl

## Relationship to Other Skills

| Skill | Purpose |
|---|---|
| **live-debug** (this skill) | Drive browser → diagnose → fix source code → verify |
| **ogxo-debug:browser-testing** | Write Playwright test scripts for E2E / accessibility / regression |

If the user wants to *prevent the bug from coming back*, finish this loop first, then suggest a regression test (the **ogxo-debug:browser-testing** skill).

## Prerequisites

Verify in order before the first browser call. Stop and tell the user if any check fails — don't guess.

### 1. Dev server running?

Ask for the URL or probe common ports:

```bash
for port in 3000 5173 8080 4200 8000; do
  curl -sf "http://localhost:$port" -o /dev/null && echo "$port up" || echo "$port down"
done
```

### 2. Browser tooling available? (use the first one that's installed)

- **Chrome DevTools MCP** — best for diagnostics (`list_console_messages`, `list_network_requests`). Separate install; its README has the setup command for each host
- **`agent-browser`** — best token economy for interaction (`snapshot -i`, `click @e3`)
- **Playwright CLI** — fallback when neither MCP nor `agent-browser` is available

If a tool is missing, tell the user which one to install. Do not install packages globally without asking.

The steps below name actions: open a URL, snapshot interactive elements, click or fill, read console, read failed requests, screenshot. Use whichever browser tool the host provides. The `agent-browser` commands shown are one mapping, not a requirement. If no browser tool is available, say so, and debug from the dev-server terminal output and what the user copies from DevTools.

### 3. Source maps enabled?

If errors come back without filenames + line numbers, ask the user to enable source maps before continuing. Debugging minified bundles burns context for no payoff.

## The Core Loop

Follow this loop in order. Do not skip to "fix" before "diagnose."

```
        ┌──────────────────────────┐
        │ 1. OPEN + REPRODUCE      │
        │   navigate, walk steps   │
        └────────────┬─────────────┘
                     ▼
        ┌──────────────────────────┐
        │ 2. DIAGNOSE              │
        │   console + network +    │
        │   DOM snapshot + (vis)   │
        └────────────┬─────────────┘
                     ▼
        ┌──────────────────────────┐
        │ 3. HYPOTHESIZE           │
        │   locate source files    │
        └────────────┬─────────────┘
                     ▼
        ┌──────────────────────────┐
        │ 4. FIX                   │
        │   minimal targeted edit  │
        └────────────┬─────────────┘
                     ▼
        ┌──────────────────────────┐
        │ 5. VERIFY                │
        │   re-run repro, confirm  │
        └────────────┬─────────────┘
                     │ not fixed?
                     └────► back to 2
```

### Step 1: Open + Reproduce

```bash
agent-browser open http://localhost:3000/<route-with-bug>
agent-browser snapshot -i              # interactive elements only — cheap
```

If the user described reproduction steps, walk them using `@e1`, `@e2` refs from the snapshot:

```bash
agent-browser click @e3
agent-browser fill @e5 "test@example.com"
```

### Step 2: Diagnose

Read the cheapest signals first.

**Console errors first** — they usually point straight at the file and line.
- Chrome DevTools MCP: `list_console_messages`
- Otherwise: `agent-browser get cdp-url` and pipe console messages via the CDP endpoint, or ask the user to check the dev server terminal where HMR errors print

**Network failures next** — anything non-2xx during the repro.
- Chrome DevTools MCP: `list_network_requests` filtered to `status >= 400`
- Otherwise: ask the user to share failing requests from the Network tab

**DOM state** — only when console + network were clean.
- `agent-browser get text @e3` for specific element content
- `agent-browser get styles @e3` for computed styles (layout bugs)
- `agent-browser is visible @e3` / `is enabled @e3` for state checks

**Visual snapshot** — only when the bug is visual *and* text signals didn't explain it.
- `agent-browser screenshot ./bug.png` then read the image
- Most expensive step. Skip when avoidable.

### Step 3: Hypothesize

Map the symptom to source. Use the error's filename + line if you got one. Otherwise:
- Search the codebase for the failing component name, API path, or error message string
- Read the relevant file(s) and adjacent code (parent component, the API handler)
- State the hypothesis in one sentence before editing. If you can't, you don't understand the bug yet — go back to Step 2.

### Step 4: Fix

Make the smallest change that addresses the hypothesis. Resist refactoring. If the bug is in a 3-line render condition, fix those 3 lines.

**One change per iteration.** If you change more than one thing, you can't tell which fix worked.

### Step 5: Verify

Wait for HMR (1–3 seconds typically), then:

```bash
agent-browser open http://localhost:3000/<route-with-bug>
agent-browser snapshot -i
```

Re-run the original reproduction. **Both** conditions must hold:
1. The original error message is gone
2. The expected behavior is present

"No console errors" alone is not enough.

If still broken: revert your edit, return to Step 2 with the new information. Do **not** stack a second fix on top of an unverified first fix.

## Tool Selection Cheat Sheet

| Symptom | Best tool | Why |
|---|---|---|
| JS console error | Chrome DevTools MCP `list_console_messages` | Structured stack traces |
| Failed API call | Chrome DevTools MCP `list_network_requests` | Status, headers, response body |
| Element missing/wrong | `agent-browser snapshot -i` | Cheap, structured |
| Layout/styling off | `agent-browser screenshot` + vision | Text trees miss visual issues |
| Slow page | Chrome DevTools MCP perf trace | Only tool with timing data |
| State after interaction | `agent-browser get value/text` | Targeted, ~50 tokens |

## Token Economy Tactics

The point of this loop is to fit dozens of iterations in one context window. Defaults:

- Prefer interactive-only snapshots (`snapshot -i`) to full snapshots
- Screenshot only when the bug is visual, because each image read costs thousands of tokens
- Read targeted elements (`get text @e3`) instead of re-snapshotting the whole page
- Filter network calls to `status >= 400` rather than dumping all requests
- When console output is long, grep it: `agent-browser ... | grep -iE "error|warn"`
- Close the browser between unrelated tasks: `agent-browser close`

If iterations keep growing, you are re-snapshotting too much.

## Common Failure Modes

**"My fix worked but the page still shows the old behavior."**
HMR didn't fire or the page is cached. Force a hard reload (`agent-browser open <url>` again) or ask the user to restart the dev server.

**"agent-browser commands hang."**
The daemon may be stuck. Run `agent-browser close` then retry; if it still hangs, fall back to another browser tool.

**"Auth wall blocks my repro."**
Use a persistent profile so the agent inherits the user's logged-in session. The Chrome profile path varies by OS; ask the user for it:

```bash
agent-browser --profile <chrome-profile-dir> open <url>
```

**"Can't tell what changed between iterations."**
You're modifying too much per iteration. Make one change at a time and verify before stacking.

**"The bug only repros sometimes."**
Race condition. Add waits between actions (`agent-browser wait <selector>`) before re-snapshotting. Read the user's code for `useEffect` dependencies, missing `await`s, or unmounted-component state updates.

**"Console is clean, network is clean, but the UI is wrong."**
Likely a render-logic bug — wrong prop, wrong condition, missing key. Read the component source and trace data flow from the API response to the rendered output.

## Wrapping Up

When the loop terminates successfully:

1. Close the browser: `agent-browser close`
2. Summarize for the user: the symptom, the root cause in one sentence, the file(s) changed, and how you verified
3. **Do not** claim the fix is complete based on "no console errors." A passing verify step requires the *original symptom* to be gone.
4. If the bug is non-trivial, suggest a regression test as a follow-up (the **ogxo-debug:browser-testing** skill) — but write the test as a separate task, not inside this loop.

## What This Skill Deliberately Does NOT Do

- Doesn't write or run E2E test suites — that's the **ogxo-debug:browser-testing** skill
- Doesn't replace human review on visual / UX judgment calls
- Doesn't try to fix bugs in third-party code or browser quirks; surface those to the user
- Debug against local or dev URLs; open a production URL only when the user asks for it

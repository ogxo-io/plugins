# ogxo-debug

Debug a running web app by driving the browser: reproduce the symptom, read console and network errors, fix, and verify in the page.

## Install

```bash
claude plugin marketplace add ogxo-io/plugins
claude plugin install ogxo-debug@ogxo
```

## Contents

- `/ogxo-debug:live-debug` (skill)
- `/ogxo-debug:css-alignment-debug` (skill)
- `/ogxo-debug:browser-testing` (skill)

browser-testing needs no setup step: its runner uses the project's own Playwright when that has Chromium downloaded, and otherwise installs Playwright and Chromium once, which downloads a browser build (`BROWSER_TESTING_NO_INSTALL=1` turns that off). In Claude Code the install goes into the plugin's data directory; elsewhere into `${XDG_CACHE_HOME:-~/.cache}/ogxo-debug/browser-testing`.

browser-testing writes scripts and screenshots under `/tmp` with a name per run (the templates add a `RUN` id), so parallel sessions don't overwrite each other's files.

## Codex

The native `.codex-plugin/plugin.json` exports all existing debugging skills. Browser tools depend on the current host. Playwright packages and browser downloads go into `BROWSER_TESTING_HOME` when set, else `PLUGIN_DATA/browser-testing`, else `${XDG_CACHE_HOME:-~/.cache}/ogxo-debug/browser-testing`; the skill's commands use `${CLAUDE_PLUGIN_ROOT}`, which Claude Code fills in and Codex users replace with the plugin root. Set `BROWSER_TESTING_NO_INSTALL=1` to report missing dependencies without installing them.

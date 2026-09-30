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

browser-testing needs no setup step: its runner uses the project's own Playwright when that has Chromium downloaded, and otherwise installs Playwright and Chromium once into the plugin's data directory, which downloads a browser build (`BROWSER_TESTING_NO_INSTALL=1` turns that off).

browser-testing writes scripts and screenshots under `/tmp` with a name per run (the templates add a `RUN` id), so parallel sessions don't overwrite each other's files.

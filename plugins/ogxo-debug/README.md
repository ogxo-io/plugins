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

browser-testing writes scripts and screenshots under `/tmp` with a name per run (the templates add a `RUN` id), so parallel sessions don't overwrite each other's files.

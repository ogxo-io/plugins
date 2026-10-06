#!/usr/bin/env bash
# Native Codex surfaces must not export the Claude/Grok setup or telemetry.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
python3 - "$root" <<'PY'
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
expected = {
    'ogxo-route': {'routing', 'worker-procedures'},
    'ogxo-statusline': {'setup-codex'},
}
for name, skills in expected.items():
    plugin = root / 'plugins' / name
    overlay = json.loads((plugin / '.codex-plugin/plugin.json').read_text())
    original = json.loads((plugin / '.claude-plugin/plugin.json').read_text())
    assert overlay['version'] == original['version'], name
    assert overlay['skills'] == './codex-skills/', name
    assert overlay['hooks'] == {'hooks': {}}, 'Claude hooks must not auto-discover'
    exported = plugin / overlay['skills']
    assert {p.parent.name for p in exported.glob('*/SKILL.md')} == skills
    for path in exported.glob('*/SKILL.md'):
        text = path.read_text()
        assert text.startswith('---\nname: '), path
        assert text.endswith('\n') and not text.endswith('\n\n'), path
        assert '${CLAUDE_PLUGIN_ROOT}' not in text or name == 'ogxo-route'

setup = (root / 'plugins/ogxo-statusline/codex-skills/setup-codex/SKILL.md').read_text()
assert '/statusline' in setup and 'tui.status_line' in setup
assert 'config.toml' in setup
assert 'does not execute the command' in ' '.join(setup.split())
assert 'TOML has no null' in setup
assert not list((root / 'plugins/ogxo-statusline/codex-skills').glob('**/*.sh'))
print('PASS: Codex native routing/statusline exports and telemetry separation')
PY

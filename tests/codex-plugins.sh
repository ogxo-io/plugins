#!/usr/bin/env bash
# Check Codex exports separately from Claude's component discovery.
# --runtime additionally reads every package through the installed Codex app server.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
python3 - "$root" "${1:-}" <<'PY'
import json
import pathlib
import re
import selectors
import subprocess
import sys
import time

root = pathlib.Path(sys.argv[1])
catalog = root / '.claude-plugin/marketplace.json'
plugins = json.loads(catalog.read_text())['plugins']
expected = {}
for entry in plugins:
    package = root / entry['source']
    manifest_path = package / '.codex-plugin/plugin.json'
    assert manifest_path.is_file(), f'{entry["name"]}: missing Codex manifest'
    manifest = json.loads(manifest_path.read_text())
    claude = json.loads((package / '.claude-plugin/plugin.json').read_text())
    assert manifest['name'] == entry['name']
    assert manifest['version'] == entry['version'] == claude['version'], entry['name']
    roots = manifest.get('skills', [])
    if isinstance(roots, str):
        roots = [roots]
    names = set()
    for skill_root in roots:
        assert skill_root.startswith('./'), skill_root
        path = (package / skill_root).resolve()
        assert path.is_relative_to(package.resolve()) and path.is_dir(), path
        for skill in path.glob('*/SKILL.md'):
            body = skill.read_text()
            assert body.startswith('---\n'), skill
            header = body.split('---', 2)[1]
            name = re.search(r'^name:\s*(.+)$', header, re.M)
            description = re.search(r'^description:\s*(.+)$', header, re.M)
            assert name and description, skill
            # Codex skills point at shared sources; each pointer must resolve.
            for ref in re.findall(r'(?:\.\./)+[A-Za-z0-9_./-]+\.(?:md|sh|js|py|json)', body):
                target = (skill.parent / ref).resolve()
                assert target.is_relative_to(package.resolve()), f'{skill}: {ref} leaves the package'
                assert target.is_file(), f'{skill}: {ref} does not exist'
            qualified = entry['name'] + ':' + name.group(1).strip(' \"\'')
            assert qualified not in names, f'duplicate skill {qualified}'
            names.add(qualified)
    hooks = manifest.get('hooks')
    if isinstance(hooks, str):
        assert hooks.startswith('./')
        hook_path = package / hooks
        assert hook_path.is_file(), hook_path
        assert isinstance(json.loads(hook_path.read_text())['hooks'], dict)
    # Codex still discovers hooks/hooks.json when "hooks" is [] or absent;
    # only an empty inline hook map turns that discovery off.
    assert hooks != [], f'{entry["name"]}: "hooks": [] does not disable hook discovery; use {{"hooks": {{}}}}'
    assert not (hooks is None and (package / 'hooks/hooks.json').is_file()), \
        f'{entry["name"]}: Codex auto-discovers hooks/hooks.json; set "hooks" explicitly'
    if entry['name'] in ('ogxo-route', 'ogxo-statusline'):
        assert hooks == {'hooks': {}}, f'{entry["name"]}: default Claude hooks must be disabled'
    expected[entry['name']] = names

for package in ('ogxo-git', 'ogxo-review'):
    for command in (root / 'plugins' / package / 'commands').glob('*.md'):
        assert package + ':' + command.stem in expected[package], command
for package in ('ogxo-specialists', 'ogxo-decide'):
    for agent in (root / 'plugins' / package / 'agents').glob('*.md'):
        assert package + ':' + agent.stem in expected[package], agent
assert 'ogxo:setup' in expected['ogxo']
assert 'ogxo-statusline:setup-codex' in expected['ogxo-statusline']
assert 'ogxo-statusline:setup' not in expected['ogxo-statusline']
print(f'Codex exports: {len(plugins)} packages, {sum(map(len, expected.values()))} skills; versions and resource paths match')

if sys.argv[2] == '--runtime':
    proc = subprocess.Popen(['codex', 'app-server'], stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    selector = selectors.DefaultSelector()
    selector.register(proc.stdout, selectors.EVENT_READ)
    try:
        def request(rid, method, params):
            proc.stdin.write(json.dumps({'id': rid, 'method': method, 'params': params}) + '\n')
            proc.stdin.flush()
            deadline = time.monotonic() + 30
            while time.monotonic() < deadline:
                if not selector.select(1):
                    if proc.poll() is not None:
                        raise RuntimeError(proc.stderr.read())
                    continue
                line = proc.stdout.readline()
                if not line:
                    raise RuntimeError(proc.stderr.read())
                response = json.loads(line)
                if response.get('id') == rid:
                    assert 'error' not in response, response
                    return response['result']
            raise TimeoutError(f'{method}: no response')
        request(1, 'initialize', {'clientInfo': {'name': 'ogxo-plugin-check', 'version': '1'},
                                 'capabilities': {'experimentalApi': True}})
        for rid, entry in enumerate(plugins, 2):
            plugin = request(rid, 'plugin/read', {'pluginName': entry['name'],
                             'marketplacePath': str(catalog)})['plugin']
            actual = {skill['name'] for skill in plugin['skills']}
            assert actual == expected[entry['name']], (entry['name'], actual, expected[entry['name']])
            if entry['name'] in ('ogxo-route', 'ogxo-statusline'):
                assert plugin['hooks'] == [], (entry['name'], plugin['hooks'])
            if entry['name'] in ('ogxo-guards', 'ogxo-format'):
                assert plugin['hooks'], entry['name']
            print(f'Codex runtime: {entry["name"]} loads {len(actual)} skills, {len(plugin["hooks"])} hooks')
    finally:
        selector.close()
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
PY

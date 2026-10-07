#!/usr/bin/env python3
"""Register a Codex HTTP server with a Keychain helper, preserving config on failure."""
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile


def main():
    name, url, security, account = sys.argv[1:]
    home = Path(os.environ.get("CODEX_HOME") or Path.home() / ".codex").expanduser()
    home.mkdir(parents=True, exist_ok=True)
    config = home / "config.toml"
    original = config.read_bytes() if config.exists() else None
    # Resolve symlinks so an existing linked config keeps its target.
    config = config.resolve()
    code = (
        'import json, subprocess; token = subprocess.check_output('
        + repr([security, "find-generic-password", "-s", "thryx-mcp", "-a", account, "-w"])
        + ', text=True).rstrip("\\n"); '
        + 'assert token, "ThryX Keychain token is empty"; '
        + 'print(json.dumps({"Authorization": "Bearer " + token}))'
    )
    helper = shlex.join([sys.executable, "-c", code])
    # mcp add has no helper option. Let Codex serialize the entry in a private
    # copy, then insert the helper in its canonical table before publishing it.
    with tempfile.TemporaryDirectory(prefix=".thryx-connect-", dir=home) as staging:
        candidate = Path(staging) / "config.toml"
        if original is not None:
            candidate.write_bytes(original)
        subprocess.run(
            ["codex", "mcp", "add", name, "--url", url],
            env=dict(os.environ, CODEX_HOME=staging),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=True,
        )
        text = candidate.read_text()
        header = "[mcp_servers." + name + "]\n"
        if text.count(header) != 1:
            raise RuntimeError("could not locate the generated MCP entry")
        text = text.replace(header, header + "http_headers_helper = " + json.dumps(helper) + "\n", 1)
        candidate.write_text(text.rstrip("\n") + "\n")
        current = config.read_bytes() if config.exists() else None
        if current != original:
            raise RuntimeError("Codex configuration changed during setup; retry")
        os.chmod(candidate, config.stat().st_mode & 0o777 if config.exists() else 0o600)
        # Keep the final rename on the target filesystem, including symlink targets.
        fd, pending = tempfile.mkstemp(prefix=".thryx-connect-", dir=config.parent)
        os.close(fd)
        try:
            shutil.copyfile(candidate, pending)
            os.chmod(pending, candidate.stat().st_mode & 0o777)
            os.replace(pending, config)
        finally:
            if os.path.exists(pending):
                os.unlink(pending)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        # Exceptions do not contain tokens; do not print subprocess output or config.
        print("thryx: could not configure Codex Keychain authentication: " + str(error), file=sys.stderr)
        sys.exit(1)

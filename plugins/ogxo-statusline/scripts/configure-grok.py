#!/usr/bin/env python3
"""Insert, replace, or remove the [ui.status_line] table in Grok's user config.

Other lines stay as they are, including comments and blank lines that sit
above the next table. The table is found by its parsed key, so spellings such
as `[ ui.status_line ]` or `[ui."status_line"]` count. The script refuses when
status_line is set with inline keys or sub-tables, when the table appears more
than once, or when the file is not valid TOML, and leaves the file unchanged in
those cases. When tomllib is available (Python 3.11+), the edited text is
parsed before it is written, and a result that does not parse, or does not
hold the intended table, is refused rather than written.

The config path is $GROK_HOME/config.toml, or ~/.grok/config.toml. A symlink
is followed and the target is the file that is edited. --home selects another
directory (used by tests).
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:  # Python < 3.11: skip the parse check
    tomllib = None

HEADER = "[ui.status_line]"
KEY = ("ui", "status_line")
BARE_KEY_CHARS = set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")


def grok_home(explicit: str | None) -> Path:
    if explicit:
        return Path(explicit).expanduser()
    env = os.environ.get("GROK_HOME")
    if env:
        return Path(env).expanduser()
    return Path.home() / ".grok"


def command_for(home: Path) -> str:
    default = Path.home() / ".grok"
    try:
        same = home.resolve() == default.resolve()
    except OSError:
        same = False
    if same:
        return "~/.grok/ogxo-statusline.sh"
    return str(home / "ogxo-statusline.sh")


def edit_path(config: Path) -> Path:
    if config.is_symlink():
        return Path(os.path.realpath(config))
    return config


def toml_string(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def table_text(command: str) -> str:
    return (
        "[ui.status_line]\n"
        'type = "command"\n'
        f"command = {toml_string(command)}\n"
        "padding = 0\n"
        "refresh_interval = 60\n"
    )


def split_lines(text: str) -> list[str]:
    if text == "":
        return []
    return text.splitlines(keepends=True)


def parse_dotted_key(text: str) -> tuple[str, ...] | None:
    """Split a TOML dotted key into its parts; None when it is not one."""
    parts: list[str] = []
    i, n = 0, len(text)
    while True:
        while i < n and text[i] in " \t":
            i += 1
        if i >= n:
            return None
        if text[i] in "\"'":
            quote = text[i]
            i += 1
            buf: list[str] = []
            while i < n and text[i] != quote:
                if quote == '"' and text[i] == "\\" and i + 1 < n:
                    buf.append(text[i + 1])
                    i += 2
                    continue
                buf.append(text[i])
                i += 1
            if i >= n:
                return None
            i += 1
            parts.append("".join(buf))
        else:
            start = i
            while i < n and text[i] in BARE_KEY_CHARS:
                i += 1
            if i == start:
                return None
            parts.append(text[start:i])
        while i < n and text[i] in " \t":
            i += 1
        if i >= n:
            return tuple(parts)
        if text[i] != ".":
            return None
        i += 1


def header_key(line: str) -> tuple[str, tuple[str, ...]] | None:
    """("table" | "array", key) for a table header line, else None."""
    stripped = line.strip()
    if not stripped.startswith("["):
        return None
    kind, open_len, close = ("array", 2, "]]") if stripped.startswith("[[") else ("table", 1, "]")
    close_at = stripped.find(close, open_len)
    while close_at != -1:
        rest = stripped[close_at + len(close):].strip()
        if rest == "" or rest.startswith("#"):
            key = parse_dotted_key(stripped[open_len:close_at])
            return (kind, key) if key else None
        close_at = stripped.find(close, close_at + 1)
    return None


def is_table_header(line: str) -> bool:
    return header_key(line) is not None


def is_trailing_trivia(line: str) -> bool:
    body = line.strip()
    return body == "" or body.startswith("#")


def find_table(lines: list[str]) -> tuple[int, int] | None:
    starts = [i for i, line in enumerate(lines) if header_key(line) == ("table", KEY)]
    if not starts:
        return None
    if len(starts) > 1:
        raise ValueError("ambiguous")
    start = starts[0]
    end = len(lines)
    for i in range(start + 1, len(lines)):
        if is_table_header(lines[i]):
            end = i
            break
    # Blank lines and comments just above the next table belong to it, so
    # they are neither replaced on install nor deleted on uninstall.
    if end < len(lines):
        while end > start + 1 and is_trailing_trivia(lines[end - 1]):
            end -= 1
    return start, end


def find_inline(lines: list[str]) -> list[str]:
    hits: list[str] = []
    header: tuple[str, ...] = ()
    for line in lines:
        stripped = line.strip()
        parsed = header_key(line)
        if parsed is not None:
            kind, key = parsed
            header = key
            # A sub-table or array under ui.status_line also sets it.
            if key[: len(KEY)] == KEY and (kind == "array" or len(key) > len(KEY)):
                hits.append(stripped)
            continue
        if stripped.startswith("ui.status_line") or stripped.startswith("ui . status_line"):
            hits.append(stripped)
        elif header == ("ui",) and (
            stripped.startswith("status_line.")
            or stripped.startswith("status_line ")
            or stripped.startswith("status_line=")
        ):
            hits.append(stripped)
    return hits


def shell_words(command: str) -> list[str]:
    words: list[str] = []
    i = 0
    n = len(command)
    while i < n:
        while i < n and command[i].isspace():
            i += 1
        if i >= n:
            break
        if command[i] in "\"'":
            quote = command[i]
            i += 1
            buf: list[str] = []
            while i < n and command[i] != quote:
                if command[i] == "\\" and quote == '"' and i + 1 < n:
                    buf.append(command[i + 1])
                    i += 2
                    continue
                buf.append(command[i])
                i += 1
            if i < n and command[i] == quote:
                i += 1
            words.append("".join(buf))
        else:
            start = i
            while i < n and not command[i].isspace():
                i += 1
            words.append(command[start:i])
    return words


def quoted_value(raw: str) -> str:
    value = raw.strip()
    if not value:
        return ""
    if value[0] in "\"'":
        words = shell_words(value)
        return words[0] if words else ""
    if " #" in value:
        value = value.split(" #", 1)[0]
    return value.strip()


def assignments(lines: list[str], start: int, end: int) -> dict[str, str]:
    found: dict[str, str] = {}
    for line in lines[start + 1 : end]:
        body = line.strip()
        if not body or body.startswith("#") or "=" not in body:
            continue
        key, value = body.split("=", 1)
        found[key.strip()] = quoted_value(value)
    return found


def expand_command(value: str) -> str:
    if value.startswith("~/"):
        return str(Path.home() / value[2:])
    return str(Path(value).expanduser())


def same_program(command: str, expected: str) -> bool:
    words = shell_words(command)
    if not words:
        return False
    try:
        return os.path.normpath(expand_command(words[0])) == os.path.normpath(
            expand_command(expected)
        )
    except (OSError, ValueError):
        return False


def classify(lines: list[str], expected: str) -> tuple[str, dict]:
    inline = find_inline(lines)
    if inline:
        return "inline", {"inline": inline}
    try:
        span = find_table(lines)
    except ValueError:
        return "ambiguous", {}
    if span is None:
        return "absent", {}
    start, end = span
    vals = assignments(lines, start, end)
    info = {
        "type": vals.get("type", ""),
        "command": vals.get("command", ""),
        "start": start,
        "end": end,
    }
    if vals.get("type") == "command" and same_program(vals.get("command", ""), expected):
        return "match", info
    return "other", info


def backup(path: Path) -> None:
    if path.is_file() and not path.is_symlink():
        path.with_name(path.name + ".bak").write_bytes(path.read_bytes())


def write_file(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def parse_check(original: str, updated: str, command: str | None) -> str | None:
    """Why the edit must not be written, or None when it is safe.

    command is the table install writes; None means uninstall, which must
    leave no status_line behind. Without tomllib the check is skipped.
    """
    if tomllib is None:
        return None
    try:
        tomllib.loads(original)
    except tomllib.TOMLDecodeError as exc:
        return f"config.toml is not valid TOML ({exc}); fix it before running setup"
    try:
        data = tomllib.loads(updated)
    except tomllib.TOMLDecodeError as exc:
        return f"the edited file would not parse ({exc})"
    table = data.get("ui", {}).get("status_line")
    if command is None:
        return None if table is None else "status_line is still set after the edit"
    want = {"type": "command", "command": command, "padding": 0, "refresh_interval": 60}
    return None if table == want else "the edited file does not hold the intended table"


def refuse(edit: Path, reason: str) -> int:
    print(f"config={edit}")
    print("status=refused")
    print(f"reason={reason}")
    return 3


def load(config: Path) -> tuple[Path, list[str]]:
    edit = edit_path(config) if config.exists() or config.is_symlink() else config
    text = edit.read_text() if edit.is_file() else ""
    return edit, split_lines(text)


def print_table(lines: list[str], start: int, end: int) -> None:
    print("---")
    sys.stdout.write("".join(lines[start:end]))
    if lines[start:end] and not lines[end - 1].endswith("\n"):
        print()
    print("---")


def cmd_check(config: Path, expected: str) -> int:
    edit, lines = load(config)
    status, info = classify(lines, expected)
    print(f"config={edit}")
    print(f"command_expected={expected}")
    print(f"status={status}")
    if status == "inline":
        for hit in info["inline"]:
            print(f"inline={hit}")
    elif status in ("match", "other"):
        print(f"type={info.get('type', '')}")
        print(f"command={info.get('command', '')}")
        print_table(lines, info["start"], info["end"])
    return 0


def cmd_install(config: Path, expected: str, command: str) -> int:
    edit, lines = load(config)
    status, info = classify(lines, expected)
    if status in ("inline", "ambiguous"):
        print(f"config={edit}")
        print(f"status={status}")
        for hit in info.get("inline", []):
            print(f"inline={hit}")
        return 2
    new_table = split_lines(table_text(command))
    if status == "absent":
        body = "".join(lines)
        if body and not body.endswith("\n"):
            body += "\n"
        if body and not body.endswith("\n\n"):
            body += "\n"
        updated = body + table_text(command)
    else:
        start, end = info["start"], info["end"]
        rest = lines[end:]
        if rest and rest[0].strip() != "":
            new_table = new_table + ["\n"]
        updated = "".join(lines[:start] + new_table + rest)
        if updated and not updated.endswith("\n"):
            updated += "\n"
    reason = parse_check("".join(lines), updated, command)
    if reason:
        return refuse(edit, reason)
    backup(edit)
    write_file(edit, updated)
    print(f"config={edit}")
    print("status=installed")
    print(f"command={command}")
    return 0


def cmd_uninstall(config: Path, expected: str) -> int:
    edit, lines = load(config)
    if not edit.is_file():
        print(f"config={edit}")
        print("status=absent")
        return 0
    status, info = classify(lines, expected)
    print(f"config={edit}")
    if status == "absent":
        print("status=absent")
        return 0
    if status != "match":
        print(f"status={status}")
        if status == "other":
            print(f"type={info.get('type', '')}")
            print(f"command={info.get('command', '')}")
        for hit in info.get("inline", []):
            print(f"inline={hit}")
        return 1 if status == "other" else 2
    start, end = info["start"], info["end"]
    updated = "".join(lines[:start] + lines[end:])
    if start == 0:
        updated = updated.lstrip("\n")
    reason = parse_check("".join(lines), updated, None)
    if reason:
        return refuse(edit, reason)
    backup(edit)
    if updated.strip() == "":
        edit.unlink()
        print("status=removed")
        print("file=deleted")
        return 0
    if not updated.endswith("\n"):
        updated += "\n"
    write_file(edit, updated)
    print("status=removed")
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("check", "install", "uninstall"))
    parser.add_argument("--home", help="Grok home to use instead of $GROK_HOME or ~/.grok")
    parser.add_argument(
        "--command",
        help="shell command to write on install; default is the ogxo script path",
    )
    args = parser.parse_args(argv)
    home = grok_home(args.home)
    config = home / "config.toml"
    expected = command_for(home)
    command = args.command if args.command else expected
    if args.action == "check":
        return cmd_check(config, expected)
    if args.action == "install":
        return cmd_install(config, expected, command)
    return cmd_uninstall(config, expected)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

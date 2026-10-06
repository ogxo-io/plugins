# Each plugin carries this small parser so either can be installed alone.
# Native Codex apply_patch supplies patch text in tool_input.command; Codex
# reports exec_command as Bash, and intercepts a command that is an
# `apply_patch`/`applypatch` heredoc, optionally after `cd <dir> &&`.
# Codex 0.160.1 parses both forms with parse_patch (apply-patch/src/lib.rs:370,
# invocation.rs:116 and :123), which runs StreamingPatchParser (parser.rs:201-203).
# Mirrored from streaming_parser.rs: one trailing CR is dropped (:143); at the
# top level and after Add or Delete, headers match after a full Unicode trim
# (:176); inside an Update section only trailing whitespace is trimmed
# (:227-229), so a line starting with a space there is a context line (:318);
# Move to counts only before the first hunk line and only once (:253-256).
# Where Codex rejects the whole patch instead (a tab-indented header inside
# Update, a later Move to, a header after End Patch), this still matches after
# the full trim and keeps every path, so the guards see more paths, not fewer.
# The lookbehind keeps the trailing match linear on long interior runs.
def trim_ws: gsub("^[\\s\\p{Z}]+|(?<![\\s\\p{Z}])[\\s\\p{Z}]+$"; "");
def patch_files($text):
  reduce ($text | split("\n")[] | rtrimstr("\r")) as $line
    ({files: [], mode: "top", hunk: false};
      if .mode == "update" and ($line | startswith(" ")) then .hunk = true
      else ($line | trim_ws) as $t
      | if ($t | startswith("*** Add File: ")) then
        .files[.files | length] = {path: ($t | ltrimstr("*** Add File: ")), kind: "add", added: 0}
        | .mode = "add"
      elif ($t | startswith("*** Update File: ")) then
        .files[.files | length] = {path: ($t | ltrimstr("*** Update File: ")), kind: "update", added: 0}
        | .mode = "update" | .hunk = false
      elif ($t | startswith("*** Delete File: ")) then
        .files[.files | length] = {path: ($t | ltrimstr("*** Delete File: ")), kind: "delete", added: 0}
        | .mode = "delete"
      elif $t == "*** End Patch" then .mode = "top"
      elif ($t | startswith("*** Move to: ")) then
        ($t | ltrimstr("*** Move to: ")) as $dest
        | if .mode == "update" and (.hunk | not) and .files[-1].destination == null then
            .files[-1].destination = $dest
          else .files[.files | length] = {path: $dest, kind: "update", added: 0} end
      else
        (if .mode == "update" and ($line == "" or ($line | test("^[+-]"))
            or $t == "@@" or ($t | startswith("@@ "))) then .hunk = true else . end)
        | if ($line | startswith("+")) and (.files | length > 0) then
            # The + prefix has the same character length as the added newline.
            .files[-1].added += ($line | length)
          else . end
      end end)
  | .files;
# Heredoc body after the `apply_patch <<DELIM` line, and the `cd` operand.
# Blanks in the prefix may be backslash-newline continuations, and assignment
# words may come before `cd` or `apply_patch`, as in a shell command line.
def shell_patch:
  "(?:[ \\t]|\\\\\\n)" as $b
  | "(?:[A-Za-z_][A-Za-z0-9_]*=(?:'[^']*'|\"[^\"]*\"|\\\\[^\\n]|[^\\s;&|'\"\\\\])*\($b)+)*" as $env
  | (.tool_input.command // "")
  | (capture("^[\\s\\p{Z}]*(\($env)cd\($b)+(?<dir>'[^']*'|\"[^\"]*\"|(?:\\\\[^\\n]|[^\\s;&|\\\\])+)\($b)*&&(?:\\s|\\\\\\n)*)?\($env)(apply_patch|applypatch)\($b)*<<(?!<)[^\\n]*\\n(?<body>[\\s\\S]*)$") // null)
  | if . == null then []
    else (.dir // "" | if test("^'.*'$|^\".*\"$") then .[1:-1] else . end) as $dir
    | patch_files(.body)
    | map(if $dir == "" then . else
        (.path |= if startswith("/") then . else $dir + "/" + . end)
        | if .destination then
            .destination |= if startswith("/") then . else $dir + "/" + . end
          else . end
      end)
    end;
if .tool_name == "apply_patch" then patch_files(.tool_input.command // "")
elif .tool_name == "Bash" then shell_patch
else [{path: (.tool_input.file_path // ""), kind: "write",
       added: ((.tool_input.content // "") | length)}] end

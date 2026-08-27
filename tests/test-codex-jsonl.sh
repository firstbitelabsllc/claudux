#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/test-harness.sh"

success() { printf '%s\n' "$*"; }

source "$REPO_ROOT/lib/codex-utils.sh"

echo "=== Codex JSONL Formatter Tests ==="
echo ""

reordered_output=$(
    cat <<'JSONL' | format_codex_output_stream 2>&1
{"item":{"metadata":{"path":"/ignored/path","type":"file_change"},"command":"echo reordered","type":"command_execution"},"metadata":{"type":"item.completed"},"type":"item.started"}
{"item":{"text":"nested decoy","type":"agent_message"},"type":"turn.started"}
JSONL
)
assert_contains "reordered keys find top-level and item types" "$reordered_output" "Running [1]: echo reordered"
assert_not_contains "nested type fields do not change event meaning" "$reordered_output" "nested decoy"
assert_contains "reordered event keeps final counters" "$reordered_output" "Codex finished (1 commands, 0 files, 0 messages)"

escaped_output=$(
    cat <<'JSONL' | format_codex_output_stream 2>&1
{"item":{"text":"Found \"README.md\" at C:\\work\\docs\nnext line after slash \\ and quote \"done\"","type":"agent_message"},"type":"item.completed"}
JSONL
)
assert_contains "escaped quotes and backslashes are unescaped" "$escaped_output" 'Agent: Found "README.md" at C:\work\docs'
assert_contains "escaped newlines do not truncate following text" "$escaped_output" 'next line after slash \ and quote "done"'
assert_contains "escaped message increments message count" "$escaped_output" "Codex finished (0 commands, 0 files, 1 messages)"

paths_output=$(
    cat <<'JSONL' | format_codex_output_stream 2>&1
{"item":{"changes":[{"path":"/repo/docs/guide \"quoted\".md","kind":"update"},{"kind":"add","path":"/repo/docs/back\\slash.md"}],"type":"file_change"},"type":"item.started"}
JSONL
)
assert_contains "quoted file path keeps its basename" "$paths_output" 'Writing [1]: guide "quoted".md'
assert_contains "backslash file path is not truncated" "$paths_output" 'Writing [2]: back\slash.md'
assert_contains "file changes keep final counters" "$paths_output" "Codex finished (0 commands, 2 files, 0 messages)"

failed_output=$(
    cat <<'JSONL' | format_codex_output_stream 2>&1
{"item":{"status":"completed","command":"cp \"C:\\src\\file\" \"C:\\dst\\file\"\nretry","exit_code":9,"metadata":{"type":"agent_message"},"type":"command_execution"},"type":"item.completed"}
JSONL
)
assert_contains "failed command keeps quotes and paths" "$failed_output" 'Command failed (exit 9): cp "C:\src\file" "C:\dst\file"'
assert_contains "failed command keeps text after escaped newline" "$failed_output" "retry"

usage_output=$(
    cat <<'JSONL' | format_codex_output_stream 2>&1
{"metadata":{"usage":{"input_tokens":999999,"output_tokens":999999}},"usage":{"output_tokens":34,"cached_input_tokens":12,"input_tokens":1234},"type":"turn.completed"}
JSONL
)
assert_contains "usage counts come from the structural usage object" "$usage_output" "Turn complete — tokens: 1234 in / 34 out"
assert_not_contains "nested usage fields do not override counts" "$usage_output" "999999"

malformed_output=$(
    cat <<'JSONL' | format_codex_output_stream 2>&1
not json
{"type":
[{"type":"item.completed","item":{"type":"agent_message","text":"array decoy"}}]
{"type":"item.completed","item":{"type":"agent_message","text":"survived malformed input"}}
JSONL
)
malformed_status=$?
assert_eq "malformed and non-JSON lines are ignored" "0" "$malformed_status"
assert_contains "valid events after malformed lines still render" "$malformed_output" "Agent: survived malformed input"
assert_not_contains "non-object JSON is ignored" "$malformed_output" "array decoy"

combined_output=$(
    cat <<'JSONL' | format_codex_output_stream 2>&1
{"type":"item.started","item":{"type":"command_execution","command":"echo count"}}
{"type":"item.started","item":{"type":"file_change","changes":[{"path":"/repo/a.md"},{"path":"/repo/b.md"}]}}
{"type":"item.completed","item":{"type":"agent_message","text":"counted"}}
JSONL
)
assert_contains "combined stream reports exact final counters" "$combined_output" "Codex finished (1 commands, 2 files, 1 messages)"

test_summary

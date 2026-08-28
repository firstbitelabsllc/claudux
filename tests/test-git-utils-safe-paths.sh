#!/usr/bin/env bash
# Behavioral coverage for NUL-delimited git status path handling.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/claudux-git-utils-test-XXXXXX")
trap 'rm -rf "$TEST_ROOT"' EXIT

pass=0
fail=0

assert_contains() {
    local label="$1"
    local haystack="$2"
    local needle="$3"

    if [[ "$haystack" == *"$needle"* ]]; then
        echo "  PASS $label"
        pass=$((pass + 1))
    else
        echo "  FAIL $label"
        printf '       missing: %s\n' "$needle"
        fail=$((fail + 1))
    fi
}

assert_not_contains() {
    local label="$1"
    local haystack="$2"
    local needle="$3"

    if [[ "$haystack" != *"$needle"* ]]; then
        echo "  PASS $label"
        pass=$((pass + 1))
    else
        echo "  FAIL $label"
        printf '       unexpected: %s\n' "$needle"
        fail=$((fail + 1))
    fi
}

assert_eq() {
    local label="$1"
    local expected="$2"
    local actual="$3"

    if [[ "$actual" == "$expected" ]]; then
        echo "  PASS $label"
        pass=$((pass + 1))
    else
        echo "  FAIL $label"
        printf '       expected: %s\n' "$expected"
        printf '       actual:   %s\n' "$actual"
        fail=$((fail + 1))
    fi
}

create_repo() {
    local repo="$1"

    mkdir -p "$repo"
    (
        cd "$repo" || exit 1
        git init -q
        git config user.email "test@example.com"
        git config user.name "Test User"
        git config core.quotePath true
    )
}

info() {
    printf 'INFO %s\n' "$1"
}

warn() {
    printf 'WARN %s\n' "$1"
}

success() {
    printf 'SUCCESS %s\n' "$1"
}

print_color() {
    shift
    printf 'COLOR %s\n' "$1"
}

# shellcheck source=/dev/null
source "$REPO_ROOT/lib/git-utils.sh"

echo "=== git-utils safe path tests ==="

weird_repo="$TEST_ROOT/weird-paths"
create_repo "$weird_repo"
(
    cd "$weird_repo" || exit 1
    mkdir -p docs
    printf 'rename source\n' > 'docs/rename old -> "quoted" café.md'
    printf 'tracked\n' > 'docs/space name.md'
    printf 'delete\n' > 'docs/delete -> me.md'
    git add -- docs
    git commit -q -m "initial docs"

    renamed_path=$'docs/rename new\tline\n -> "quoted" café.md'
    staged_path=$'docs/staged\tname café.md'
    untracked_path=$'docs/untracked\nline\t -> "quoted" café.md'

    git mv -- 'docs/rename old -> "quoted" café.md' "$renamed_path"
    printf 'updated\n' >> 'docs/space name.md'
    git add -- 'docs/space name.md'
    git rm -q -- 'docs/delete -> me.md'
    printf 'staged\n' > "$staged_path"
    git add -- "$staged_path"
    printf 'untracked\n' > "$untracked_path"
)

weird_summary=$(
    cd "$weird_repo" || exit 1
    show_git_status
)

assert_contains \
    "summary keeps spaces and literal arrows unambiguous" \
    "$weird_summary" \
    'D  "docs/delete -> me.md"'
assert_contains \
    "summary preserves raw unicode instead of git octal quoting" \
    "$weird_summary" \
    'A  "docs/staged\tname café.md"'
assert_contains \
    "summary escapes tabs and newlines without splitting the path" \
    "$weird_summary" \
    '?? "docs/untracked\nline\t -> \"quoted\" café.md"'
assert_contains \
    "summary renders both rename paths in source-to-destination order" \
    "$weird_summary" \
    'R  "docs/rename old -> \"quoted\" café.md" -> "docs/rename new\tline\n -> \"quoted\" café.md"'
assert_not_contains \
    "summary does not leak git quotePath octal escapes" \
    "$weird_summary" \
    '\303\251'

weird_details=$(
    cd "$weird_repo" || exit 1
    show_detailed_changes
) 2>&1

assert_contains \
    "details classify staged additions with the exact weird path" \
    "$weird_details" \
    'Created: "docs/staged\tname café.md" - New documentation file'
assert_contains \
    "details classify staged modifications with spaces" \
    "$weird_details" \
    'Updated: "docs/space name.md" - Content synchronized with codebase'
assert_contains \
    "details classify deletions containing literal arrows" \
    "$weird_details" \
    'Deleted: "docs/delete -> me.md" - Obsolete or duplicate content removed'
assert_contains \
    "details preserve both paths for renames" \
    "$weird_details" \
    'Renamed: "docs/rename old -> \"quoted\" café.md" -> "docs/rename new\tline\n -> \"quoted\" café.md" - File reorganized'
assert_contains \
    "details classify untracked paths containing tabs and newlines" \
    "$weird_details" \
    'Added: "docs/untracked\nline\t -> \"quoted\" café.md" - New documentation generated'

count_repo="$TEST_ROOT/counts"
create_repo "$count_repo"
(
    cd "$count_repo" || exit 1
    mkdir -p docs
    printf 'source\n' > docs/00-rename-source.md
    git add -- docs/00-rename-source.md
    git commit -q -m "rename source"
    git mv -- docs/00-rename-source.md docs/00-rename-target.md

    for number in 01 02 03 04 05 06 07 08 09 10 11; do
        printf 'untracked\n' > "docs/count-$number.md"
    done
)

count_summary=$(
    cd "$count_repo" || exit 1
    show_git_status
)
displayed_count=$(printf '%s\n' "$count_summary" | grep -Ec '^(R |\?\?) ')

assert_eq "summary displays exactly ten logical status entries" "10" "$displayed_count"
assert_contains \
    "summary counts a rename as one file despite its second NUL field" \
    "$count_summary" \
    '   ... and 2 more files'
assert_contains \
    "summary does not truncate a displayed rename between its paths" \
    "$count_summary" \
    'R  "docs/00-rename-source.md" -> "docs/00-rename-target.md"'

echo ""
echo "git-utils safe paths: $pass passed, $fail failed"
exit "$fail"

#!/bin/bash
# Run all claudux tests — plain bash, no dependencies
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOTAL_EXIT=0

echo "╔════════════════════════════════════════╗"
echo "║       claudux test suite               ║"
echo "╚════════════════════════════════════════╝"
echo ""

for test_file in "$SCRIPT_DIR"/test-*.sh; do
    # Skip the harness itself
    [[ "$(basename "$test_file")" == "test-harness.sh" ]] && continue

    echo ""
    case "$(head -n 1 "$test_file")" in
        "#!/bin/bash")
            /bin/bash "$test_file"
            ;;
        "#!/usr/bin/env bash")
            /usr/bin/env bash "$test_file"
            ;;
        "#!/bin/sh")
            /bin/sh "$test_file"
            ;;
        *)
            echo "Unsupported test interpreter: $test_file" >&2
            false
            ;;
    esac
    ec=$?
    if [[ $ec -ne 0 ]]; then
        TOTAL_EXIT=1
    fi
    echo ""
done

echo ""
if [[ $TOTAL_EXIT -eq 0 ]]; then
    echo "All test suites passed."
else
    echo "Some tests failed."
fi

exit $TOTAL_EXIT

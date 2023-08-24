#!/bin/bash
# Simplified runner for cmake

set -ex

runwasi="$1"
target="$2"
stdout_expected="$3"
stderr_expected="/dev/null"

stdout_observed="$target.stdout.observed"
stderr_observed="$target.stderr.observed"

"$runwasi" "$target" > "$stdout_observed" 2> "$stderr_observed"

diff -u "$stderr_expected" "$stderr_observed"
diff -u "$stdout_expected" "$stdout_observed"

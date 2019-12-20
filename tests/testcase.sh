#!/bin/bash
set -ueo pipefail

# A simple testcase runner that runs a command, captures all its command-line
# outputs, and compares them against expected outputs.

# Command-line parsing; this script is meant to be run from a higher-level
# script, so don't do anything fancy.
runwasi="$1"
clang="$2"
options="$3"
input="$4"

# Compile names for generated files.
wasm="$input.$options.wasm"
stdout_observed="$input.$options.stdout.observed"
stderr_observed="$input.$options.stderr.observed"
exit_status_observed="$input.$options.exit_status.observed"

# Optionally load compiler options from a file.
if [ -e "$input.options" ]; then
    file_options=$(cat "$input.options")
else
    file_options=
fi

echo "Testing $input..."

# Determine the input file to write to stdin.
"$clang" $options $file_options "$input" -o "$wasm"
if [ -e "$input.stdin" ]; then
  stdin="$input.stdin"
else
  stdin="/dev/null"
fi

# Run the test, capturing stdout, stderr, and the exit status.
exit_status=0
"$runwasi" "$wasm" \
    < "$stdin" \
    > "$stdout_observed" \
    2> "$stderr_observed" \
    || exit_status=$?
echo $exit_status > "$exit_status_observed"

# Determine the reference files to compare with.
if [ -e "$input.stdout.expected" ]; then
  stdout_expected="$input.stdout.expected"
else
  stdout_expected="/dev/null"
fi
if [ -e "$input.stderr.expected" ]; then
  stderr_expected="$input.stderr.expected"
else
  stderr_expected="/dev/null"
fi
if [ -e "$input.exit_status.expected" ]; then
  exit_status_expected="$input.exit_status.expected"
else
  exit_status_expected=../exit_status_zero
fi

# If there are any differences, diff will return a non-zero exit status, and
# since this script uses "set -e", it will return a non-zero exit status too.
diff -u "$stderr_expected" "$stderr_observed"
diff -u "$stdout_expected" "$stdout_observed"
diff -u "$exit_status_expected" "$exit_status_observed"

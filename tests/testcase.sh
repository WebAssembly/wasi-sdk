#!/bin/bash
set -ueo pipefail

# A simple testcase runner that runs a command, captures all its command-line
# outputs, and compares them against expected outputs.

# Command-line parsing; this script is meant to be run from a higher-level
# script, so don't do anything fancy.
runwasi="$1"
input="$2"
wasm="$3"

# Compile names for generated files.
stdout_observed="$wasm.stdout.observed"
stderr_observed="$wasm.stderr.observed"
exit_status_observed="$wasm.exit_status.observed"

# Double-check that a runwasi command was specified since otherwise this script
# was invoked with no arguments which isn't as intended.
if [ "$runwasi" == "" ]; then
    exit 1
fi

# Determine the input file to write to stdin.
if [ -e "$input.stdin" ]; then
  stdin="$input.stdin"
else
  stdin="/dev/null"
fi

# Determine any environment variables to set.
if [ -e "$input.env" ]; then
    env=$(sed -e 's/^/--env /' < "$input.env")
else
    env=""
fi

# Determine a preopened directory to provide.
if [ -e "$input.dir" ]; then
    dir="--dir $input.dir"
    dirarg="$input.dir"
else
    dir=""
    dirarg=""
fi

# Run the test, capturing stdout, stderr, and the exit status.
exit_status=0
"$runwasi" $env $dir "$wasm" $dirarg \
    < "$stdin" \
    > "$stdout_observed" \
    2> "$stderr_observed" \
    || exit_status=$?
echo $exit_status > "$exit_status_observed"

# Determine the reference files to compare with.
if [ -e "$input.stdout.expected" ]; then
  stdout_expected="$input.stdout.expected"

  # Apply output filters.
  if [ -e "$input.stdout.expected.filter" ]; then
      cat "$stdout_observed" \
          | "$input.stdout.expected.filter" \
          > "${stdout_observed}.filtered"
      stdout_observed="${stdout_observed}.filtered"
  fi
else
  stdout_expected="/dev/null"
fi

if [ -e "$input.stderr.expected" ]; then
  stderr_expected="$input.stderr.expected"

  # Apply output filters.
  if [ -e "$input.stderr.expected.filter" ]; then
      cat "$stderr_observed" \
          | "./$input.stderr.expected.filter" \
          > "${stderr_observed}.filtered"
      stderr_observed="${stderr_observed}.filtered"
  fi
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
diff --ignore-space-change -u "$stderr_expected" "$stderr_observed"
diff --ignore-space-change -u "$stdout_expected" "$stdout_observed"
diff --ignore-space-change -u "$exit_status_expected" "$exit_status_observed"

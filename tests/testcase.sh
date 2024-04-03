#!/bin/bash
set -ueo pipefail

# A simple testcase runner that runs a command, captures all its command-line
# outputs, and compares them against expected outputs.

# Command-line parsing; this script is meant to be run from a higher-level
# script, so don't do anything fancy.
target="$1"
runwasi="$2"
adapter="$3"
wasm_tools="$4"
compiler="$5"
options="$6"
input="$7"

# Compile names for generated files.
wasm="$input.$options.wasm"
stdout_observed="$input.$options.stdout.observed"
stderr_observed="$input.$options.stderr.observed"
exit_status_observed="$input.$options.exit_status.observed"
run_args=""

# Optionally load compiler options from a file.
if [ -e "$input.options" ]; then
    file_options=$(cat "$input.options")
else
    file_options=
fi

if echo "$target" | grep -q -- '-threads$'; then
    pthread_options="-pthread"
else
    pthread_options=
fi

echo "Testing $input..."

# Compile the testcase.
$compiler $pthread_options $options $file_options "$input" -o "$wasm"

# If we don't have a runwasi command, we're just doing compile-only testing.
if [ "$runwasi" == "" ]; then
    exit 0
fi

if [ "$target" == "wasm32-wasip2" -a -n "$adapter" -a -n "$wasm_tools" ]; then
    "$wasm_tools" component new --adapt "$adapter" "$wasm" -o "$wasm"
    run_args="--wasm component-model"
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
"$runwasi" $run_args $env $dir "$wasm" $dirarg \
    < "$stdin" \
    > "$stdout_observed" \
    2> "$stderr_observed" \
    || exit_status=$?
echo $exit_status > "$exit_status_observed"

# Determine the reference files to compare with.
if [ -e "$input.stdout.expected" ]; then
  if [ -e "$input.$target.stdout.expected" ]; then
      stdout_expected="$input.$target.stdout.expected"
  else
      stdout_expected="$input.stdout.expected"
  fi

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
  if [ -e "$input.$target.stderr.expected" ]; then
      stderr_expected="$input.$target.stderr.expected"
  else
      stderr_expected="$input.stderr.expected"
  fi

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
diff -u "$stderr_expected" "$stderr_observed"
diff -u "$stdout_expected" "$stdout_observed"
diff -u "$exit_status_expected" "$exit_status_observed"

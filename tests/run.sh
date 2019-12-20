#!/bin/bash
set -ueo pipefail

# Top-level test runner. Usage is "run.sh <runwasi>" where <runwasi> is a
# WASI-capable runtime.

runwasi="$1"

cd compile-only
for options in -O0 -O2 "-O2 -flto"; do
    echo "===== Testing compile-only with $options ====="
    for file in *.c; do
        echo "Testing compile-only $file..."
        ../testcase.sh true clang "$options" "$file"
    done
    for file in *.cc; do
        echo "Testing compile-only $file..."
        ../testcase.sh true clang++ "$options" "$file"
    done
done
cd - >/dev/null

cd general
for options in -O0 -O2 "-O2 -flto"; do
    echo "===== Testing with $options ====="
    for file in *.c; do
        echo "Testing $file..."
        ../testcase.sh "$runwasi" clang "$options" "$file"
    done
    for file in *.cc; do
        echo "Testing $file..."
        ../testcase.sh "$runwasi" clang++ "$options" "$file"
    done
done
cd - >/dev/null

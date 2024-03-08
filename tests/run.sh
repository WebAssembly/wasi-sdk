#!/bin/bash
set -ueo pipefail

# Top-level test runner. Usage is "run.sh <path to wasi-sdk>" to run tests
# in compile-only mode, or "run.sh <path to wasi-sdk> <runwasi>" where
# <runwasi> is a WASI-capable runtime to run the tests in full compile and
# execute mode.
#
# The compiler used during testing is loaded from `<path to wasi-sdk>`.
if [ $# -lt 1 ]; then
    echo "Path to WASI SDK is required"
    exit 1
fi

wasi_sdk="$1"

# Determine the wasm runtime to use, if one is provided.
if [ $# -gt 1 ]; then
    runwasi="$2"
    if [ $# -gt 3 ]; then
        adapter="$3"
        wasm_tools="$4"
    else
        adapter=""
        wasm_tools=""
    fi
else
    runwasi=""
    adapter=""
    wasm_tools=""
fi

testdir=$(dirname $0)

echo "SDK: $wasi_sdk"

# NB: all tests are run with the default `clang` and `clang++` executables
# but they're also executed with the target-prefixed `clang` executables to
# ensure that those work as well when the `--target` option is omitted.

for target in $TARGETS; do
    echo "===== Testing target $target ====="
    cd $testdir/compile-only
    for options in -O0 -O2 "-O2 -flto"; do
        echo "===== Testing compile-only with $options ====="
        for file in *.c; do
            echo "Testing compile-only $file..."
            ../testcase.sh "$target" "" "" "" "$wasi_sdk/bin/clang" "$options --target=$target" "$file"
            ../testcase.sh "$target" "" "" "" "$wasi_sdk/bin/$target-clang" "$options" "$file"
        done
        for file in *.cc; do
            echo "Testing compile-only $file..."
            ../testcase.sh "$target" "" "" "" "$wasi_sdk/bin/clang++" "$options --target=$target -fno-exceptions" "$file"
            ../testcase.sh "$target" "" "" "" "$wasi_sdk/bin/$target-clang++" "$options -fno-exceptions" "$file"
        done
    done
    cd - >/dev/null

    cd $testdir/general
    for options in -O0 -O2 "-O2 -flto"; do
        echo "===== Testing with $options ====="
        for file in *.c; do
            echo "Testing $file..."
            ../testcase.sh "$target" "$runwasi" "$adapter" "$wasm_tools" "$wasi_sdk/bin/clang" "$options --target=$target" "$file"
            ../testcase.sh "$target" "$runwasi" "$adapter" "$wasm_tools" "$wasi_sdk/bin/$target-clang" "$options" "$file"
        done
        for file in *.cc; do
            echo "Testing $file..."
            ../testcase.sh "$target" "$runwasi" "$adapter" "$wasm_tools" "$wasi_sdk/bin/clang++" "$options --target=$target -fno-exceptions" "$file"
            ../testcase.sh "$target" "$runwasi" "$adapter" "$wasm_tools" "$wasi_sdk/bin/$target-clang++" "$options -fno-exceptions" "$file"
        done
    done
    cd - >/dev/null
done

# Test cmake build system for wasi-sdk
test_cmake() {
    local option
    for option in Debug Release; do
        rm -rf "$testdir/cmake/build/$option"
        mkdir -p "$testdir/cmake/build/$option"
        cd "$testdir/cmake/build/$option"
        cmake \
            -G "Unix Makefiles" \
            -DCMAKE_BUILD_TYPE="$option" \
            -DRUNWASI="$runwasi" \
            -DWASI_SDK_PREFIX="$wasi_sdk" \
            -DCMAKE_TOOLCHAIN_FILE="$wasi_sdk/share/cmake/wasi-sdk.cmake" \
            ../..
        make
        if [[ -n "$runwasi" ]]; then
            ctest --output-on-failure
        fi
        cd - >/dev/null
    done
}

test_cmake

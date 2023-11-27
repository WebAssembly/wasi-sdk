#!/bin/bash
set -ueo pipefail

# Top-level test runner. Usage is "run.sh <path to wasi-sdk>" to run tests
# in compile-only mode, or "run.sh <path to wasi-sdk> <runwasi>" where
# <runwasi> is a WASI-capable runtime to run the tests in full compile and
# execute mode.
#
# By default this script will look for `clang` and `clang++` in $PATH and
# assume that they are correctly configured with the sysroot in the default
# location.  Alternatively, exporting $CC and $CXX allow more flexibility. e.g:
#
#  export CXX="<wasi-sdk>/bin/clang++ --sysroot <wasi-sdk>/share/wasi-sysroot"
#  export CC="<wasi-sdk>/bin/clang --sysroot <wasi-sdk>/share/wasi-sysroot"
#
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
CC=${CC:=clang}
CXX=${CXX:=clang++}

echo $CC
echo $CXX
echo "SDK: $wasi_sdk"

# TODO: `wasm32-wasi-threads` should be in this list, but as of this writing the
# `signal.c` test is failing due to https://github.com/bytecodealliance/wasmtime/issues/7745
for target in wasm32-wasi-preview2 wasm32-wasi; do
    echo "===== Testing target $target ====="
    cd $testdir/compile-only
    for options in -O0 -O2 "-O2 -flto"; do
        echo "===== Testing compile-only with $options ====="
        for file in *.c; do
            echo "Testing compile-only $file..."
            ../testcase.sh "$target" "" "" "" "$CC" "$options" "$file"
        done
        for file in *.cc; do
            echo "Testing compile-only $file..."
            ../testcase.sh "$target" "" "" "" "$CXX" "$options" "$file"
        done
    done
    cd - >/dev/null
    
    cd $testdir/general
    for options in -O0 -O2 "-O2 -flto"; do
        echo "===== Testing with $options ====="
        for file in *.c; do
            echo "Testing $file..."
            ../testcase.sh "$target" "$runwasi" "$adapter" "$wasm_tools" "$CC" "$options" "$file"
        done
        for file in *.cc; do
            echo "Testing $file..."
            ../testcase.sh "$target" "$runwasi" "$adapter" "$wasm_tools" "$CXX" "$options" "$file"
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

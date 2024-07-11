#!/bin/bash

# Build logic executed in CI. This is intentionally kept relatively minimal to
# one day not live in bash to have a bash-less build on Windows. For now though
# this will unconditionally build a toolchain and then optionally build a
# sysroot. Builders which can't actually execute the toolchain they produce
# skip the sysroot step below.

set -ex

# Optionally allow the first argument to this script to be the install
# location.
if [ "$1" = "" ]; then
  install_dir=`pwd`/build/install
else
  install_dir="$1"
fi

cmake -G Ninja -B build/toolchain -S . \
  -DWASI_SDK_BUILD_TOOLCHAIN=ON \
  "-DCMAKE_INSTALL_PREFIX=$install_dir" \
  $WASI_SDK_CI_TOOLCHAIN_CMAKE_ARGS \
  "-DLLVM_CMAKE_FLAGS=$WASI_SDK_CI_TOOLCHAIN_LLVM_CMAKE_ARGS"
ninja -C build/toolchain install dist -v

mv build/toolchain/dist build/dist

if [ "$WASI_SDK_CI_SKIP_SYSROOT" = "1" ]; then
  exit 0
fi

# Use the just-built toolchain and its `CMAKE_TOOLCHAIN_FILE` to build a
# sysroot.
cmake -G Ninja -B build/sysroot -S . \
  "-DCMAKE_TOOLCHAIN_FILE=$install_dir/share/cmake/wasi-sdk.cmake" \
  -DCMAKE_C_COMPILER_WORKS=ON \
  -DCMAKE_CXX_COMPILER_WORKS=ON \
  -DWASI_SDK_INCLUDE_TESTS=ON \
  "-DCMAKE_INSTALL_PREFIX=$install_dir"
ninja -C build/sysroot install dist -v

mv build/sysroot/dist/* build/dist

if [ "$WASI_SDK_CI_SKIP_TESTS" = "1" ]; then
  exit 0
fi

# Run tests to ensure that the sysroot works.
ctest --output-on-failure --parallel 10 --test-dir build/sysroot/tests

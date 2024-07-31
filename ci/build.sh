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
  build_dir=`pwd`/build
else
  build_dir="$1"
fi

cmake -G Ninja -B $build_dir/toolchain -S . \
  -DWASI_SDK_BUILD_TOOLCHAIN=ON \
  -DCMAKE_BUILD_TYPE=MinSizeRel \
  "-DCMAKE_INSTALL_PREFIX=$build_dir/install" \
  $WASI_SDK_CI_TOOLCHAIN_CMAKE_ARGS \
  "-DLLVM_CMAKE_FLAGS=$WASI_SDK_CI_TOOLCHAIN_LLVM_CMAKE_ARGS"
ninja -C $build_dir/toolchain install dist -v

mv $build_dir/toolchain/dist $build_dir/dist

if [ "$WASI_SDK_CI_SKIP_SYSROOT" = "1" ]; then
  exit 0
fi

# Use the just-built toolchain and its `CMAKE_TOOLCHAIN_FILE` to build a
# sysroot.
cmake -G Ninja -B $build_dir/sysroot -S . \
  "-DCMAKE_TOOLCHAIN_FILE=$build_dir/install/share/cmake/wasi-sdk.cmake" \
  -DCMAKE_C_COMPILER_WORKS=ON \
  -DCMAKE_CXX_COMPILER_WORKS=ON \
  -DWASI_SDK_INCLUDE_TESTS=ON \
  "-DCMAKE_INSTALL_PREFIX=$build_dir/install"
ninja -C $build_dir/sysroot install dist -v

mv $build_dir/sysroot/dist/* $build_dir/dist

if [ "$WASI_SDK_CI_SKIP_TESTS" = "1" ]; then
  exit 0
fi

# Run tests to ensure that the sysroot works.
ctest --output-on-failure --parallel 10 --test-dir $build_dir/sysroot/tests \
  --timeout 60

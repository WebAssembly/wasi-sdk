#!/bin/sh
set -ex

rm -r build/llvm build/llvm.BUILT
NINJA_FLAGS=-v make strip LLVM_CMAKE_FLAGS="-DLLVM_CCACHE_BUILD=ON -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ -DCMAKE_CROSSCOMPILING=True -DCMAKE_CXX_FLAGS=-march=armv8-a -DCMAKE_SYSTEM_PROCESSOR=arm64 -DCMAKE_SYSTEM_NAME=Linux -DLLVM_HOST_TRIPLE=aarch64-linux-gnu"
CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc cargo install wasm-component-ld@0.5.0 --root "$(pwd)/build/install/opt/wasi-sdk" --target aarch64-unknown-linux-gnu
mkdir -p dist
./deb_from_installation.sh "$(pwd)/dist" "$(./version.py)" "$(pwd)/build/install/opt/wasi-sdk" "arm64"
./tar_from_installation.sh "$(pwd)/dist" "$(./version.py)" "$(pwd)/build/install/opt/wasi-sdk" "linux-arm64"

#!/bin/sh
set -ex
echo "Building the docker image"
docker build -t wasi-sdk-builder:latest .
echo "Building the package in docker image"
mkdir -p ~/.ccache
docker run --rm -v "$PWD":/workspace -v ~/.ccache:/root/.ccache -e NINJA_FLAGS=-v --workdir /workspace --tmpfs /tmp:exec wasi-sdk-builder:latest make package LLVM_CMAKE_FLAGS=-DLLVM_CCACHE_BUILD=ON

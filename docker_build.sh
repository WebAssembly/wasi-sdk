#!/bin/sh
set -ex
echo "Building the docker image"
docker build -t wasi-sdk-builder:latest .

if ! git config safe.directory | grep /workspace; then
    echo "Setting up Git safe directory"
    git config --add safe.directory /workspace
fi

echo "Building the package in docker image"
mkdir -p ~/.ccache
docker run --rm -v "$PWD":/workspace:Z -v ~/.ccache:/root/.ccache:Z -e NINJA_FLAGS=-v --workdir /workspace --tmpfs /tmp:exec wasi-sdk-builder:latest make package LLVM_CMAKE_FLAGS=-DLLVM_CCACHE_BUILD=ON

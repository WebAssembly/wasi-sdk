#!/bin/sh
set -ex

echo "Building the docker image"
docker build \
    --build-arg UID=$(id -u) --build-arg GID=$(id -g) \
    -t wasi-sdk-builder:latest .

echo "Building the package in docker image"
mkdir -p ~/.ccache
docker run --rm \
    --user $(id -u):$(id -g) \
    -v "$PWD":/workspace:Z \
    -v ~/.ccache:/home/builder/.ccache:Z \
    -e NINJA_FLAGS=-v \
    --tmpfs /tmp:exec \
    wasi-sdk-builder:latest \
    make package LLVM_CMAKE_FLAGS=-DLLVM_CCACHE_BUILD=ON

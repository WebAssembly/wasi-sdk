#!/usr/bin/env sh
set -e
echo "Building the docker"
docker build -t wasi-sdk-builder:latest .
echo "Building the package in docker"
docker run --mount type=bind,src=$PWD,target=/workspace -e NINJA_FLAGS=-v --workdir /workspace wasi-sdk-builder:latest make package

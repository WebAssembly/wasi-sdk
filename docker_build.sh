#!/usr/bin/env sh
set -e
docker build -t wasi-sdk-builder:latest .
docker run --mount type=bind,src=$PWD,target=/wasi-sdk wasi-sdk-builder:latest -w /wasi-sdk make package

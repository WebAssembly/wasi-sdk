#!/bin/sh

# This is a helper script invoked from CI which will execute the `ci/build.sh`
# script within a docker container. This builds `ci/docker/Dockerfile.common`
# along with the specified `ci/docker/Dockerfile.$x` from the command line.
# This container is then used to execute `ci/build.sh`.

set -e

if [ "$1" = "" ]; then
  echo "Usage: $0 <image>"
  echo ""
  echo "example: $0 x86_64-linux"
  exit 1
fi

set -x

# Build the base image which the image below can used.
docker build \
  --file ci/docker/Dockerfile.common \
  --tag wasi-sdk-builder-base \
  ci/docker

# Build the container that is going to be used
docker build \
  --file ci/docker/Dockerfile.$1 \
  --tag wasi-sdk-builder \
  ci/docker

# Perform the build in `/src`. The current directory is mounted read-write at
# this location as well. To ensure that container-created files are reasonable
# on the host as well the `--user` is passed to configure various permissions.
args="--workdir /src --volume `pwd`:/src:Z"
args="$args --user $(id -u):$(id -g)"

# Persist the ccache directory on the host to ensure repeated runs/debugging
# of this container don't take forever. Also enables caching in CI.
ccache_dir=$CCACHE_DIR
if [ "$ccache_dir" = "" ]; then
  ccache_dir=$HOME/.ccache
fi
args="$args --volume $ccache_dir:/ccache:Z --env CCACHE_DIR=/ccache"

# Inherit some tools from the host into this container. This ensures that the
# decision made on CI of what versions to use is the canonical source of truth
# for theset ools
args="$args --volume `rustc --print sysroot`:/rustc:ro"
args="$args --volume $(dirname $(which wasmtime)):/wasmtime:ro"

# Pass through some env vars that `build.sh` reads
args="$args --env WASI_SDK_CI_TOOLCHAIN_CMAKE_ARGS"
args="$args --env WASI_SDK_CI_TOOLCHAIN_LLVM_CMAKE_ARGS"
args="$args --env WASI_SDK_CI_SKIP_SYSROOT"
args="$args --env WASI_SDK_CI_SKIP_TESTS"

# Before running `ci/build.sh` set up some rust/PATH related info to use what
# was just mounted above, and then execute the build.
docker run \
  $args \
  --tty \
  --init \
  wasi-sdk-builder \
  bash -c 'CARGO_HOME=/tmp/cargo-home PATH=$PATH:/rustc/bin:/wasmtime exec ci/build.sh'

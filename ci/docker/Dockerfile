# Use a relatively old/stable distro here to maximize the supported platforms
# and avoid depending on more recent version of, say, libc.
# Here we choose Ubuntu 20.04.

FROM ubuntu:20.04

# Various build tooling and such necessary to build LLVM and a wasi-sysroot
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  ccache \
  curl \
  ca-certificates \
  build-essential \
  clang \
  python3 \
  git \
  unzip \
  xz-utils \
  cmake \
  ninja-build

# Tell programs to cache in a location that both isn't a `--volume` mounted root
# and isn't `/root` in the container as that won't be writable during the build.
ENV XDG_CACHE_HOME /tmp/cache

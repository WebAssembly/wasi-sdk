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
  xz-utils

# Install a more recent version of CMake than what 18.04 has since that's what
# LLVM requires.
RUN ARCH=$(uname -m) \
  && curl -sSLO https://github.com/Kitware/CMake/releases/download/v3.29.5/cmake-3.29.5-linux-${ARCH}.tar.gz \
  && tar xf cmake-3.29.5-linux-${ARCH}.tar.gz \
  && rm cmake-3.29.5-linux-${ARCH}.tar.gz \
  && mkdir -p /opt \
  && mv cmake-3.29.5-linux-${ARCH} /opt/cmake

ENV PATH /opt/cmake/bin:$PATH

# As with CMake install a later version of Ninja than waht 18.04 has.
RUN ARCH=$(uname -m) \
  && if [ "$ARCH" = "aarch64"  ]; then SUFFIX=-aarch64; fi \
  && curl -sSL -o ninja.zip https://github.com/ninja-build/ninja/releases/download/v1.12.1/ninja-linux${SUFFIX}.zip \
  && unzip ninja.zip \
  && rm *.zip \
  && mv ninja /opt/cmake/bin

# Tell programs to cache in a location that both isn't a `--volume` mounted root
# and isn't `/root` in the container as that won't be writable during the build.
ENV XDG_CACHE_HOME /tmp/cache

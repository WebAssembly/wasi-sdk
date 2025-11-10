#!/bin/bash

# AlmaLinux 8, the container this script runs in, does not have ccache in its
# package repositories. The ccache project publishes both x86_64 and aarch64
# binaries, however. The x86_64 binaries for ccache are themselves built in
# AlmaLinux 8 so they're compatible, but the aarch64 binaries are built in a
# newer container and don't run on AlmaLinux 8.
#
# Thus this script downloads precompiled binaries for x86_64 but builds from
# source on aarch64.

ARCH=$(uname -m)
ver=4.12.1

if [ "x$ARCH" = "x86_64" ]; then
  curl -sSLO https://github.com/ccache/ccache/releases/download/v${ver}/ccache-${ver}-linux-${ARCH}.tar.xz
  tar -xf ccache-${ver}-linux-${ARCH}.tar.xz
  rm ccache-${ver}-linux-${ARCH}.tar.xz
  mv ccache-${ver}-linux-${ARCH} /opt/ccache/bin
else
  curl -sSLO https://github.com/ccache/ccache/releases/download/v${ver}/ccache-${ver}.tar.xz
  tar -xf ccache-${ver}.tar.xz

  cd ccache-${ver}
  mkdir build
  cd build
  cmake .. \
    -DCMAKE_INSTALL_PREFIX=/opt/ccache \
    -DCMAKE_BUILD_TYPE=Release \
    -DHTTP_STORAGE_BACKEND=OFF \
    -DENABLE_TESTING=OFF \
    -DREDIS_STORAGE_BACKEND=OFF
  make -j$(nproc)
  make install
fi

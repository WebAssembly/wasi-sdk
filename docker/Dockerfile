# A container which has a number of build tools pre-installed plus a build of
# `wasi-sdk` installed at `/opt/wasi-sdk`. This also has environment variables
# pre-configued to use the installed toolchain.
#
# This container is built as the last step on CI for this repository and
# pre-built versions of this container are pushed as a package to the repository
# as well.

FROM ubuntu:24.04

RUN apt-get update && \
    apt-get install -y cmake ninja-build make autoconf autogen automake libtool && \
    rm -rf /var/lib/apt/lists/*

ADD dist/wasi-sdk-*.deb .
RUN case `dpkg --print-architecture` in \
  amd64) dpkg -i wasi-sdk-*-x86_64-linux.deb ;; \
  arm64) dpkg -i wasi-sdk-*-arm64-linux.deb ;; \
  *) exit 1 ;; \
  esac && \
  rm wasi-sdk-*.deb

ENV CC="/opt/wasi-sdk/bin/clang"
ENV CXX="/opt/wasi-sdk/bin/clang++"
ENV LD="/opt/wasi-sdk/bin/wasm-ld"
ENV AR="/opt/wasi-sdk/bin/llvm-ar"
ENV RANLIB="/opt/wasi-sdk/bin/llvm-ranlib"

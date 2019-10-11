# Use a relatively old/stable distro here to maximize the supported platforms
# and avoid depending on more recent version of, say, libc.
FROM debian:stretch

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        build-essential \
        clang \
        cmake \
        python \
        git \
        ninja-build \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

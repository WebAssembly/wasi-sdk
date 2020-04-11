# Use a relatively old/stable distro here to maximize the supported platforms
# and avoid depending on more recent version of, say, libc.
# Here we choose Xenial 16.04 which mean we also support Debian from stretch
# (releases 2017) onwards.
FROM ubuntu:xenial

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

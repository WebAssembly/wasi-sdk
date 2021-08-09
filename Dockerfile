# Use a relatively old/stable distro here to maximize the supported platforms
# and avoid depending on more recent version of, say, libc.
# Here we choose Bionic 18.04.
FROM ubuntu:bionic

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        build-essential \
        clang \
        python3 \
        git \
        ninja-build \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN curl -sSLO https://github.com/Kitware/CMake/releases/download/v3.20.1/cmake-3.20.1-linux-x86_64.tar.gz \
  && tar xf cmake-3.20.1-linux-x86_64.tar.gz \
  && rm cmake-3.20.1-linux-x86_64.tar.gz \
  && mkdir -p /opt \
  && mv cmake-3.20.1-linux-x86_64 /opt/cmake
ENV PATH /opt/cmake/bin:$PATH

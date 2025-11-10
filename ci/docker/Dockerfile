# Use a relatively old/stable distro here to maximize the supported platforms
# and avoid depending on more recent version of, say, libc.
# Here we choose AlmaLinux 8

FROM almalinux:8

# Various build tooling and such necessary to build LLVM and a wasi-sysroot
RUN dnf install -y \
  curl \
  ca-certificates \
  clang \
  python3 \
  git \
  unzip \
  cmake

COPY ./install-ccache.sh .
RUN ./install-ccache.sh

ENV PATH /opt/ccache/bin:$PATH

# AlmaLinux 8 doesn't seem to have ninja, so install it manually.
RUN ARCH=$(uname -m) \
  && if [ "$ARCH" = "aarch64"  ]; then SUFFIX=-aarch64; fi \
  && curl -sSL -o ninja.zip https://github.com/ninja-build/ninja/releases/download/v1.12.1/ninja-linux${SUFFIX}.zip \
  && unzip ninja.zip \
  && rm *.zip \
  && mv ninja /opt/ccache/bin

# Tell programs to cache in a location that both isn't a `--volume` mounted root
# and isn't `/root` in the container as that won't be writable during the build.
ENV XDG_CACHE_HOME /tmp/cache

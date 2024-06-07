# Docker image with a build toolchain and environment variables set to use
# the wasi-sdk sysroot. The SDK distribution must have first been built,
# for example using docker_build.sh

# Extract built SDK archive to copy out the sysroot. We use an initial build
# stage to do this to make sure it is only the sysroot, not the entire SDK
# with binaries, that is included in the final image since we install those
# separately.
FROM ubuntu:22.04 as dist

ADD dist/wasi-sdk-*.*-linux-amd64.tar.gz /
ADD dist/libclang_rt.builtins-wasm32-wasi-*.*.tar.gz /wasi-sysroot-clang_rt

# Move versioned folder to unversioned to using bash glob to allow
# this file to be independent of major version number.
RUN mv /wasi-sdk-* /wasi-sdk

FROM ubuntu:22.04

ENV LLVM_VERSION 17

# Install build toolchain including clang, ld, make, autotools, ninja, and cmake
RUN apt-get update && \
    # Temporarily install to setup apt repositories
    apt-get install -y curl gnupg && \
\
    curl -sS https://apt.llvm.org/llvm-snapshot.gpg.key | gpg --dearmor > /etc/apt/trusted.gpg.d/llvm.gpg && \
    echo "deb [signed-by=/etc/apt/trusted.gpg.d/llvm.gpg] http://apt.llvm.org/jammy/ llvm-toolchain-jammy-${LLVM_VERSION} main" >> /etc/apt/sources.list.d/llvm.list && \
    echo "deb-src [signed-by=/etc/apt/trusted.gpg.d/llvm.gpg] http://apt.llvm.org/jammy/ llvm-toolchain-jammy-${LLVM_VERSION} main" >> /etc/apt/sources.list.d/llvm.list && \
\
    apt-get update && \
    apt-get install -y clang-${LLVM_VERSION} lld-${LLVM_VERSION} cmake ninja-build make autoconf autogen automake libtool && \
    apt-get autoremove -y curl gnupg && \
    rm -rf /var/lib/apt/lists/*

COPY --from=dist /wasi-sdk/share/wasi-sysroot/ /wasi-sysroot/
COPY --from=dist /wasi-sysroot-clang_rt/lib/wasi /usr/lib/llvm-${LLVM_VERSION}/lib/clang/${LLVM_VERSION}/lib/wasi

ADD docker/wasi-sdk.cmake /usr/share/cmake/wasi-sdk.cmake
ADD docker/wasi-sdk-pthread.cmake /usr/share/cmake/wasi-sdk-pthread.cmake
ENV CMAKE_TOOLCHAIN_FILE /usr/share/cmake/wasi-sdk.cmake
ADD cmake/Platform/WASI.cmake /usr/share/cmake/Modules/Platform/WASI.cmake

ENV CC clang-${LLVM_VERSION}
ENV CXX clang++-${LLVM_VERSION}
ENV LD wasm-ld-${LLVM_VERSION}
ENV AR llvm-ar-${LLVM_VERSION}
ENV RANLIB llvm-ranlib-${LLVM_VERSION}

ENV CFLAGS --target=wasm32-wasi --sysroot=/wasi-sysroot
ENV CXXFLAGS --target=wasm32-wasi --sysroot=/wasi-sysroot
ENV LDFLAGS --target=wasm32-wasi --sysroot=/wasi-sysroot

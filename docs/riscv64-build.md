# Building WASI SDK on riscv64

WASI SDK can be built from source on native riscv64 Linux hardware. The build
completes with zero source patches — only cmake configuration flags are needed.

## Prerequisites

- **Hardware**: Any rv64gc board with 16+ GB RAM (tested on Banana Pi F3,
  SpacemiT K1)
- **OS**: Debian Trixie or equivalent with riscv64 packages
- **Toolchain**: GCC 14+, cmake 3.26+, ninja-build, python3, git

Install build dependencies (Debian/Ubuntu):

```bash
sudo apt-get install -y build-essential cmake ninja-build python3 git ccache
```

## Build process

WASI SDK builds in two stages:

1. **Stage 1 (Toolchain)**: Builds LLVM, Clang, and LLD targeting WebAssembly.
   This is a full LLVM build and takes 8-10 hours on an 8-core rv64gc board.
2. **Stage 2 (Sysroot)**: Uses the Stage 1 compiler to build wasi-libc. Takes
   ~15-20 minutes.

### Stage 1: Build the toolchain

```bash
git clone --recursive https://github.com/WebAssembly/wasi-sdk.git
cd wasi-sdk

cmake -G Ninja -B build/toolchain -S . \
  -DWASI_SDK_BUILD_TOOLCHAIN=ON \
  -DCMAKE_BUILD_TYPE=MinSizeRel \
  -DCMAKE_INSTALL_PREFIX=$(pwd)/build/install

ninja -C build/toolchain install
```

### Stage 2: Build the sysroot

The Stage 1 compiler only targets `wasm32`, so cmake's compiler test will fail.
Use `-DCMAKE_C_COMPILER_WORKS=ON` to skip it (the CI build already does this).

WASIP2 targets require `wit-bindgen`, `wasm-tools`, and `wkg`, which are Rust
tools that don't ship riscv64 binaries. Limit targets to WASIP1:

```bash
cmake -G Ninja -B build/sysroot -S . \
  -DCMAKE_TOOLCHAIN_FILE=$(pwd)/build/install/share/cmake/wasi-sdk.cmake \
  -DCMAKE_C_COMPILER_WORKS=ON \
  -DCMAKE_CXX_COMPILER_WORKS=ON \
  -DWASI_SDK_TARGETS="wasm32-wasi;wasm32-wasip1" \
  -DCMAKE_INSTALL_PREFIX=$(pwd)/build/install

ninja -C build/sysroot install
```

### Fix resource directory path

After installation, create a symlink for the Clang resource directory so the
compiler can find its runtime libraries:

```bash
CLANG_VERSION=$(build/install/bin/clang --version | grep -oP '\d+\.\d+\.\d+')
CLANG_MAJOR=${CLANG_VERSION%%.*}
ln -sf $(pwd)/build/install/lib/clang/${CLANG_MAJOR}/lib \
       $(pwd)/build/install/lib/clang-resource-dir/lib
```

## Verification

```bash
# Compile a test program
cat > hello.c << 'EOF'
#include <stdio.h>
int main() { printf("Hello from WASI SDK on riscv64!\n"); return 0; }
EOF

build/install/bin/clang --target=wasm32-wasi --sysroot=build/install/share/wasi-sysroot \
  -o hello.wasm hello.c

file hello.wasm
# hello.wasm: WebAssembly (wasm) binary module version 0x1 (MVP)
```

If you have `iwasm` (from WAMR) installed:

```bash
iwasm hello.wasm
# Hello from WASI SDK on riscv64!
```

## Build statistics

Measured on Banana Pi F3 (SpacemiT K1, 8x rv64gc @ 1.6 GHz, 16 GB RAM):

| Metric | Value |
|--------|-------|
| Stage 1 (LLVM+Clang+LLD) | ~8-10 hours |
| Stage 2 (wasi-libc sysroot) | ~15-20 minutes |
| Installed SDK size | 244 MB |
| hello.wasm output | 105 KB |
| Source patches needed | 0 |

## Known limitations

- **WASIP2 not supported**: `wit-bindgen`, `wasm-tools`, and `wkg` do not ship
  riscv64 binaries. Only `wasm32-wasi` and `wasm32-wasip1` targets can be built.
- **No CI integration yet**: GitHub Actions does not provide riscv64 runners.
  QEMU-based builds are possible but would take many hours.
- **`wasm-component-ld` not built**: This Rust tool does not cross-compile
  easily to riscv64. It is only needed for WASIP2 component linking.

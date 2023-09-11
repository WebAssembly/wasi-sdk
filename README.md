# WASI SDK

## Quick Start

[Download SDK packages here.][releases]

[releases]: https://github.com/WebAssembly/wasi-sdk/releases

## About this repository

This repository contains no compiler or library code itself; it uses
git submodules to pull in the upstream Clang and LLVM tree, as well as the
wasi-libc tree.

The libc portion of this SDK is maintained in [wasi-libc].

[wasi-libc]: https://github.com/WebAssembly/wasi-libc

Upstream Clang and LLVM (from 9.0 onwards) can compile for WASI out of the box,
and WebAssembly support is included in them by default. So, all that's done here
is to provide builds configured to set the default target and sysroot for
convenience.

One could also use a standard Clang installation, build a sysroot from the
sources mentioned above, and compile with `--target=wasm32-wasi
--sysroot=/path/to/sysroot`. In this scenario, one would also need the
`libclang_rt.builtins-wasm32.a` objects available separately in the [release
downloads][releases] which must be extracted into
`$CLANG_INSTALL_DIR/$CLANG_VERSION/lib/wasi/`.

## Clone

This repository uses git submodule, to clone it you need use the command below :

```shell script
git clone --recursive https://github.com/WebAssembly/wasi-sdk.git
```

## Requirements

The Wasm-sdk's build process needs some packages :

* `cmake`
* `clang`
* `ninja`

Please refer to your OS documentation to install those packages.

## Build

To build the full package:

```shell script
cd wasi-sdk
NINJA_FLAGS=-v make package
```

The built package can be found into `dist` directory. For releasing a new
version of the package on GitHub, see [RELEASING.md](RELEASING.md).

## Install

A typical installation from the release binaries might look like the following:

```shell script
export WASI_VERSION=20
export WASI_VERSION_FULL=${WASI_VERSION}.0
wget https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-${WASI_VERSION}/wasi-sdk-${WASI_VERSION_FULL}-linux.tar.gz
tar xvf wasi-sdk-${WASI_VERSION_FULL}-linux.tar.gz
```

## Use

Use the clang installed in the wasi-sdk directory:

```shell script
export WASI_SDK_PATH=`pwd`/wasi-sdk-${WASI_VERSION_FULL}
CC="${WASI_SDK_PATH}/bin/clang --sysroot=${WASI_SDK_PATH}/share/wasi-sysroot"
$CC foo.c -o foo.wasm
```

Note: `${WASI_SDK_PATH}/share/wasi-sysroot` contains the WASI-specific
includes/libraries/etc. The `--sysroot=...` option is not necessary if
`WASI_SDK_PATH` is `/opt/wasi-sdk`. For troubleshooting, one can replace the
`--sysroot` path with a manual build of [wasi-libc].

### Integrating with a CMake build system

Use a toolchain file to setup the *wasi-sdk* platform.

```
$ cmake -DCMAKE_TOOLCHAIN_FILE=${WASI_SDK_PATH}/share/cmake/wasi-sdk.cmake ...
```

or the *wasi-sdk-thread* platform

```
$ cmake -DCMAKE_TOOLCHAIN_FILE=${WASI_SDK_PATH}/share/cmake/wasi-sdk-pthread.cmake ...
```

## Notes for Autoconf

[Autoconf] 2.70 now [recognizes WASI].

[Autoconf]: https://www.gnu.org/software/autoconf/autoconf.html
[recognizes WASI]: https://git.savannah.gnu.org/gitweb/?p=autoconf.git;a=blob;f=build-aux/config.sub;h=19c9553b1825cafb182115513bc628e0ee801bd0;hb=97fbc5c184acc6fa591ad094eae86917f03459fa#l1723

For convenience when building packages that aren't yet updated, updated
config.sub and config.guess files are installed at `share/misc/config.*`
in the install directory.

## Docker Image

We provide a [docker image] including wasi-sdk that can be used for building
projects without a separate installation of the SDK. Autotools, CMake, and Ninja
are included in this image, and standard environment variables are set to use
wasi-sdk for building.

[docker image]: https://github.com/WebAssembly/wasi-sdk/pkgs/container/wasi-sdk

For example, this command can build a make-based project with the Docker
image.

```
docker run -v `pwd`:/src -w /src ghcr.io/webassembly/wasi-sdk make
```

Take note of the [notable limitations](#notable-limitations) below when
building projects, for example many projects will need threads support
disabled in a configure step before building with wasi-sdk.

## Notable Limitations

This repository does not yet support __C++ exceptions__. C++ code is supported
only with -fno-exceptions for now. Similarly, there is not yet support for
setjmp/longjmp. Work on support for [exception handling] is underway at the
language level which will support both of these features.

[exception handling]: https://github.com/WebAssembly/exception-handling/

This repository experimentally supports __threads__ with
`--target=wasm32-wasi-threads`. It uses WebAssembly's [threads] primitives
(atomics, `wait`/`notify`, shared memory) and [wasi-threads] for spawning
threads. Note: this is experimental &mdash; do not expect long-term stability!

[threads]: https://github.com/WebAssembly/threads
[wasi-threads]: https://github.com/WebAssembly/wasi-threads

This repository does not yet support __dynamic libraries__. While there are
[some efforts] to design a system for dynamic libraries in wasm, it is still in
development and not yet generally usable.

[some efforts]: https://github.com/WebAssembly/tool-conventions/blob/master/DynamicLinking.md

There is no support for __networking__. It is a goal of WASI to support
networking in the future though.

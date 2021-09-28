# WASI SDK

## Quick Start

[Download SDK packages here.](https://github.com/WebAssembly/wasi-sdk/releases)

## About this repository

This repository contains no compiler or library code itself; it uses
git submodules to pull in the upstream Clang and LLVM tree, as well as the
wasi-libc tree.

The libc portion of this SDK is the
[wasi-libc](https://github.com/WebAssembly/wasi-libc).

Upstream Clang and LLVM (from 9.0 onwards) can compile for WASI out of the box,
and WebAssembly support is included in them by default. So, all that's done here
is to provide builds configured to set the default target and sysroot for
convenience.

One could also use a standard Clang installation, build a sysroot from the
sources mentioned above, and compile with
"--target=wasm32-wasi --sysroot=/path/to/sysroot".

## Install

A typical installation from the release binaries might look like the following:
```shell script
export WASI_VERSION=12
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
Note: `${WASI_SDK_PATH}/share/wasi-sysroot` contains the WASI-specific includes/libraries/etc. The `--sysroot=...` option
is not necessary if `WASI_SDK_PATH` is `/opt/wasi-sdk`.

## Notes for Autoconf

[Autoconf](https://www.gnu.org/software/autoconf/autoconf.html) 2.70 now
[recognizes WASI](https://git.savannah.gnu.org/gitweb/?p=autoconf.git;a=blob;f=build-aux/config.sub;h=19c9553b1825cafb182115513bc628e0ee801bd0;hb=97fbc5c184acc6fa591ad094eae86917f03459fa#l1723).

For convenience when building packages that aren't yet updated, updated
config.sub and config.guess files are installed at `share/misc/config.*`
in the install directory.

## Notable Limitations

This repository does not yet support C++ exceptions. C++ code is
supported only with -fno-exceptions for now. Similarly, there is not
yet support for setjmp/longjmp. Work on support for [exception handling] 
s underway at the language level which will support both of these
features.

[exception handling]: https://github.com/WebAssembly/exception-handling/

This repository does not yet support [threads]. Specifically, WASI does
not yet have an API for creating and managing threads yet, and WASI libc
does not yet have pthread support.

[threads]: https://github.com/WebAssembly/threads

This repository does not yet support dynamic libraries. While there are
[some efforts](https://github.com/WebAssembly/tool-conventions/blob/master/DynamicLinking.md)
to design a system for dynamic libraries in wasm, it is still in development
and not yet generally usable.

There is no support for networking. It is a goal of WASI to support networking
in the future though.

# WASI SDK

## Quick Start

[Download SDK packages here.](https://github.com/CraneStation/wasi-sdk/releases)

## About this repository

This repository contains no compiler or library code itself; it uses
git submodules to pull in the upstream Clang and LLVM tree, as well as the
wasi-sysroot tree.

The Sysroot portion of this SDK is the
[wasi-sysroot](https://github.com/CraneStation/wasi-sysroot).

Upstream Clang and LLVM 8.0 can compile for WASI out of the box, and WebAssembly
support is included in them by default. So, all that's done here is to provide
builds configured to set the default target and sysroot for convenience.

One could also use a standard Clang 8.0, build a sysroot from the sources
mentioned above, and compile with
"--target=wasm32-wasi --sysroot=/path/to/sysroot".

## Notes for Autoconf

Upstream autoconf now
[recognizes WASI](http://lists.gnu.org/archive/html/config-patches/2019-04/msg00001.html).

For convenience when building packages that aren't yet updated, updated
config.sub and config.guess files are installed at share/misc/config.\*
in the install directory.

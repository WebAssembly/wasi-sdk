# WASI SDK

[![Build Status](https://dev.azure.com/swiftwasm/wasi-sdk/_apis/build/status/swiftwasm.wasi-sdk?branchName=swiftwasm)](https://dev.azure.com/swiftwasm/wasi-sdk/_build/latest?definitionId=1&branchName=swiftwasm)

## Quick Start

[Download SDK packages here.](https://github.com/CraneStation/wasi-sdk/releases)

## About this repository

This repository contains no compiler or library code itself; it uses
git submodules to pull in the upstream Clang and LLVM tree, as well as the
wasi-libc tree.

The libc portion of this SDK is the
[wasi-libc](https://github.com/CraneStation/wasi-libc).

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

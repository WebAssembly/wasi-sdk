# Support for C++ Exceptions

> **Note**: this documentation does not cover wasi-sdk-31, the latest version
> of wasi-sdk at this time.

From wasi-sdk-33 and onwards the artifacts produced by this repository support
compiling C++ code both with and without exceptions. The sysroot for wasm
targets contains two copies of the C++ standard library and headers -- one with
exceptions enabled and one with exceptions disabled. These are automatically
selected based on compilation flags. This means that wasi-sdk-produced binaries
can avoid using wasm exceptions entirely by disabling C++ exceptions, or C++
exceptions can be enabled in which case wasm exceptions will be used.

Currently the default is for C++ exceptions to be disabled.

## Compiling code with C++ exceptions

Currently extra compilation flags are required to fully support C++ exceptions.
Without these flags programs using C++ exceptions will not work correctly:

* `-fwasm-exceptions` - needed to enable the WebAssembly exception-handling
  proposal.
* `-mllvm -wasm-use-legacy-eh=false` - indicates that the standard WebAssembly
  exception-handling instructions should be used.
* `-lunwind` - links in support for unwinding which C++ exceptions requires.

This can be specified for example with:

```shell script
$ export CFLAGS="-fwasm-exceptions -mllvm -wasm-use-legacy-eh=false"
$ export LDFLAGS="-fwasm-exceptions -lunwind"
```

Note that `-fwasm-exceptions` must be present when linking to select the
correct C++ standard library to link.

## Building wasi-sdk with exceptions

When building the sysroot with wasi-sdk you can pass `-DWASI_SDK_EXCEPTIONS=ON`
to enable support for C++ exceptions. For example:

```shell script
$ cmake -G Ninja -B build/sysroot -S . \
    -DCMAKE_TOOLCHAIN_FILE=$path/to/wasi-sdk-p1.cmake \
    -DWASI_SDK_EXCEPTIONS=ON
```

The C++ standard library will be compiled with support for exceptions for the
desired targets and the resulting sysroot supports using exceptions. Note that
enabling C++ exceptions requires LLVM 22 or later.

C++ exceptions are disabled by default for local builds. With a future release
of LLVM 23 the dual-sysroot nature will be on-by-default.

## Limitations

There are a few known limitations/bugs/todos around exceptions support in
wasi-sdk at this time:

* Currently C++ exceptions support in wasi-sdk does not support shared
  libraries. Fixing this will require resolving some miscellaneous build
  issues in this repository itself as well as [resolving some upstream
  issues](https://github.com/llvm/llvm-project/issues/188077).
* Currently `-fwasm-exceptions` is a required flag to enable C++ exceptions.
  It's unclear whether `-fexceptions` should also be supported as a substitute.
* Currently LLVM defaults to using the legacy exception-handling proposal and
  this will likely change in the future. Precompiled libraries for wasi-sdk are
  all built with the standard exception-handling proposal.
* Currently `-lunwind` is required when linking, but this may become automatic
  in the future.

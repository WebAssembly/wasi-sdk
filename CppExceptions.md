# Support for C++ Exceptions

The released artifacts for wasi-sdk at this time do not support C++ exceptions.
LLVM and Clang, however, have support for C++ exceptions in WebAssembly and this
is intended to serve as documentation of the current state of affairs of using
C++ exceptions. It should be noted though that the current status of C++
exceptions support is not intended to be the final state of support, and this is
all continuing to be iterated on over time.

## Building wasi-sdk with exceptions

When building the sysroot with wasi-sdk you can pass `-DWASI_SDK_EXCEPTIONS=ON`
to enable support for C++ exceptions. For example:

```shell script
$ cmake -G Ninja -B build/sysroot -S . \
    -DCMAKE_TOOLCHAIN_FILE=$path/to/wasi-sdk-p1.cmake \
    -DWASI_SDK_EXCEPTIONS=ON
```

The C++ standard library will be compiled with support for exceptions for the
desired targets and the resulting sysroot supports using exceptions.

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
$ export CFLAGS="-fwasm-exceptions -mllvm -wasm-use-legacy-eh=false -lunwind"
```

## Limitations

Currently C++ exceptions support in wasi-sdk does not support shared libraries.
Fixing this will require resolving some miscellaneous build issues in this
repository itself.

## Future Plans

There are a few tracking issues with historical discussion about C++ exceptions
support in wasi-sdk such as [#334](https://github.com/WebAssembly/wasi-sdk/issues/334)
and [#565](https://github.com/WebAssembly/wasi-sdk/issues/565). The major
remaining items are:

* Figure out support for shared libraries.
* Determine how to ship a sysroot that supports both with-and-without
  exceptions.
* Figure out how to avoid the need for extra compiler flags when using
  exceptions.
* Figure out if a new wasm target is warranted.

# C setjmp/longjmp support

WASI-SDK provides basic setjmp/longjmp support.

Note that it's still under active development and may change in
future versions.

## Build an application

To build an application using setjmp/longjmp, you need two things:

* Enable the necessary LLVM translation (`-mllvm -wasm-enable-sjlj`)

* Link the setjmp library (`-lsetjmp`)

### Example without LTO

```shell
clang -Os -mllvm -wasm-enable-sjlj -o your_app.legacy.wasm your_app.c -lsetjmp
```

### Example with LTO

```shell
clang -Os -flto=full -mllvm -wasm-enable-sjlj -Wl,-mllvm,-wasm-enable-sjlj -o your_app.legacy.wasm your_app.c -lsetjmp
```

## Run an application

To run the application built as in the previous section,
you need to use a runtime with [exception handling proposal] support.

Unfortunately, there are two incompatible versions of
[exception handling proposal], which is commonly implemented by runtimes.

* The latest version with `exnref`

* The legacy [phase3] version

### Example with the latest exception handling proposal

By default, the current version of WASI-SDK produces the legacy
"phase3" version of [exception handling proposal] instructions.

You can tell the llvm to produce the latest version of proposal by
specifying `-mllvm -wasm-use-legacy-eh=false`. This is expected
to be the default in a future version.

Alternatively, you can use binaryen `wasm-opt` command to convert
existing modules from the legacy "phase3" version to the "exnref" version.

```shell
wasm-opt --translate-to-exnref -all -o your_app.wasm your_app.legacy.wasm
```

Then you can run it with a runtime supporting the "exnref" version of
the proposal.
[toywasm] is an example of such runtimes.

```shell
toywasm --wasi your_app.wasm
```
(You may need to enable the support with `-D TOYWASM_ENABLE_WASM_EXCEPTION_HANDLING=ON`.)

### Example with the legacy phase3 exception handling proposal

If your runtime supports the legacy [phase3] version of
[exception handling proposal], which is the same version as what WASI-SDK
currently produces by default, you can run the produced module as it is.

For example, the classic interpreter of [wasm-micro-runtime] is
one of such runtimes.

```shell
iwasm your_app.legacy.wasm
```
(You may need to enable the support with `-D WAMR_BUILD_EXCE_HANDLING=1 -D WAMR_BUILD_FAST_INTERP=0`.)

[exception handling proposal]: https://github.com/WebAssembly/exception-handling/
[phase3]: https://github.com/WebAssembly/exception-handling/tree/main/proposals/exception-handling/legacy
[toywasm]: https://github.com/yamt/toywasm
[wasm-micro-runtime]: https://github.com/bytecodealliance/wasm-micro-runtime

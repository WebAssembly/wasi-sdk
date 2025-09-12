# C setjmp/longjmp support

WASI-SDK provides basic setjmp/longjmp support.

Note that it's still under active development and may change in
future versions. The tl;dr; version of this document is to pass these flags to
the C compiler:

```
-mllvm -wasm-enable-sjlj -lsetjmp -mllvm -wasm-use-legacy-eh=false
```

## Implementation Primitives

Support for `setjmp` and `longjmp` is built on top of the
[exception-handling](https://github.com/WebAssembly/exception-handling)
WebAssembly proposal. This proposal is now [phase
5](https://github.com/WebAssembly/proposals) and becoming part of the official
specification. Note, however, that the exception-handling proposal has a long
history and has a "legacy" version which shipped in browsers as well. This means
that there are two different, but similar, sets of instructions that can be
emitted to support `setjmp` and `longjmp`. Clang 20 and later (wasi-sdk-26 and
later) is capable of emitting both at this time via `-mllvm
-wasm-use-legacy-eh={false,true}` compiler flags.

Another important point is that exception-handling only provides structured
control flow primitives for exceptions. This means it is not possible to purely
define `setjmp` in C as otherwise it must be a function that returns twice. This
means that support for `setjmp` and `longjmp` in WebAssembly relies on a
compiler pass to transform invocations of `setjmp` at a compiler IR level. This
means that the `setjmp` symbol is not defined in wasi-libc, for example, but
instead primitives used to implement `setjmp`, in conjunction with LLVM, are
found in wasi-libc.

## Build an application

To build an application using setjmp/longjmp, you need three sets of compiler
flags:

1. `-mllvm -wasm-enable-sjlj`: Enable LLVM compiler pass which replaces calls to
   `setjmp` and `longjmp` with a different implementation that wasi-libc
   implements and hooks into.
2. `-lsetjmp`: Link the setjmp library that wasi-libc provides which contains
   these hooks that LLVM uses.
2. `-mllvm -wasm-use-legacy-eh=false`: Specify which version of the
   exception-handling instructions will be emitted. Note that if this is omitted
   it currently defaults to `true` meaning that the legacy instructions are
   emitted, not the standard instructions.

In short, these flags are required to use `setjmp`/`longjmp`

```
-mllvm -wasm-enable-sjlj -lsetjmp -mllvm -wasm-use-legacy-eh=false
```

### Examples

This source code:

```c
#include <assert.h>
#include <setjmp.h>
#include <stdbool.h>
#include <stdio.h>

static jmp_buf env;

static bool test_if_longjmp(void(*f)(void)) {
  if (setjmp(env))
    return true;
  f();
  return false;
}

static void do_not_longjmp() {
}

static void do_longjmp() {
  longjmp(env, 1);
}

int main() {
  bool longjmped = test_if_longjmp(do_not_longjmp);
  assert(!longjmped);
  longjmped = test_if_longjmp(do_longjmp);
  assert(longjmped);
  return 0;
}
```

can be compiled using the standard set of instructions as:

```shell
clang -Os -o test.wasm test.c \
    -mllvm -wasm-enable-sjlj -lsetjmp -mllvm -wasm-use-legacy-eh=false
```

and then `test.wasm` can be executed in a WebAssembly runtime supporting WASI.

You can also compile for the legacy exceptions proposal with:

```shell
clang -Os -o test.wasm test.c \
    -mllvm -wasm-enable-sjlj -lsetjmp -mllvm -wasm-use-legacy-eh=true
```

and then `test.wasm` can be executed in a WebAssembly runtime supporting the
legacy WebAssembly instructions.

Note that when compiling with LTO you'll need to pass `-mllvm` flags to the
linker in addition to Clang itself, such as:

```shell
clang -Os -flto=full -o test.wasm test.c \
    -mllvm -wasm-enable-sjlj -lsetjmp -mllvm -wasm-use-legacy-eh=false \
    -Wl,-mllvm,-wasm-enable-sjlj,-mllvm,-wasm-use-legacy-eh=false
```

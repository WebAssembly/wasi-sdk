# Cmake toolchain description file for the wasi-sdk docker image

# This is arbitrary, AFAIK, for now.
cmake_minimum_required(VERSION 3.4.0)

# To make sure it recognizes the WASI platform
list(APPEND CMAKE_MODULE_PATH /usr/share/cmake/Modules)

set(CMAKE_SYSTEM_NAME WASI)
set(CMAKE_SYSTEM_VERSION 1)
set(CMAKE_SYSTEM_PROCESSOR wasm32)
set(triple wasm32-wasi-threads)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -pthread")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pthread")
# wasi-threads requires --import-memory.
# wasi requires --export-memory.
# (--export-memory is implicit unless --import-memory is given)
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,--import-memory")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,--export-memory")

set(CMAKE_C_COMPILER /usr/bin/clang-$ENV{LLVM_VERSION})
set(CMAKE_CXX_COMPILER /usr/bin/clang++-$ENV{LLVM_VERSION})
set(CMAKE_ASM_COMPILER /usr/bin/clang-$ENV{LLVM_VERSION})
set(CMAKE_AR /usr/bin/llvm-ar-$ENV{LLVM_VERSION})
set(CMAKE_RANLIB /usr/bin/llvm-ranlib-$ENV{LLVM_VERSION})
set(CMAKE_C_COMPILER_TARGET ${triple})
set(CMAKE_CXX_COMPILER_TARGET ${triple})
set(CMAKE_ASM_COMPILER_TARGET ${triple})
SET(CMAKE_SYSROOT /wasi-sysroot)

# Don't look in the sysroot for executables to run during the build
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
# Only look in the sysroot (not in the host paths) for the rest
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

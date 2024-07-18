# Build logic for building both a toolchain and a sysroot for WASI.
#
# This top level `CMakeLists.txt` file can be used either to build a clang
# toolchain or a WASI sysroot. Note that this can't be done at the same time.
# A toolchain build requires a compiler for the target architecture. A
# WASI sysroot build requires this previous compiler and must be runnable on
# the host.

cmake_minimum_required(VERSION 3.26)
project(wasi-sdk)
include(ExternalProject)

set(WASI_SDK_TARGETS "wasm32-wasi;wasm32-wasip1;wasm32-wasip2;wasm32-wasip1-threads;wasm32-wasi-threads"
  CACHE STRING "List of WASI targets to build")
option(WASI_SDK_BUILD_TOOLCHAIN "Build a toolchain instead of the sysroot" OFF)

set(llvm_proj_dir ${CMAKE_CURRENT_SOURCE_DIR}/src/llvm-project)
set(wasi_libc ${CMAKE_CURRENT_SOURCE_DIR}/src/wasi-libc)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(wasi-sdk-enable-ccache)

find_program(PYTHON python3 python REQUIRED)

# Set some variables based on the `version.py` script
set(version_script ${CMAKE_CURRENT_SOURCE_DIR}/version.py)
execute_process(
  COMMAND ${PYTHON} ${version_script}
  OUTPUT_VARIABLE wasi_sdk_version
  OUTPUT_STRIP_TRAILING_WHITESPACE)

message(STATUS "wasi-sdk version is ${wasi_sdk_version}")

# Only include one version of the build logic as pulling in both isn't
# supported at this time.
if(WASI_SDK_BUILD_TOOLCHAIN)
include(wasi-sdk-toolchain)
else()
include(wasi-sdk-sysroot)
endif()

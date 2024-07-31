# Support for running tests in the `tests/{compile-only,general}` folders
cmake_minimum_required(VERSION 3.22)
project(wasi-sdk-test)
include(CTest)
enable_testing()
set(CMAKE_EXECUTABLE_SUFFIX ".wasm")

option(WASI_SDK_TEST_HOST_TOOLCHAIN "Test against the host toolchain, not a fresh sysroot" OFF)

if(NOT WASI_SDK_TEST_HOST_TOOLCHAIN)
  add_compile_options(--sysroot=${wasi_sysroot} -resource-dir ${wasi_resource_dir})
  add_link_options(--sysroot=${wasi_sysroot} -resource-dir ${wasi_resource_dir})
endif()

# Sanity check setup
if (NOT ${CMAKE_SYSTEM_NAME} STREQUAL WASI)
  message(FATAL_ERROR "Wrong system name (${CMAKE_SYSTEM_NAME}), wrong toolchain file in use?")
endif()

if(NOT DEFINED WASI)
  message(FATAL_ERROR "WASI is not set, platform file likely not loaded")
endif()

set(WASI_SDK_RUNWASI "wasmtime" CACHE STRING "Runner for tests")

# Test everything at O0, O2, and O2+LTO
set(opt_flags -O0 -O2 "-O2 -flto")

add_custom_target(build-tests)

# Executes a single `test` specified.
#
# This will compile `test` for all the various targets and with various
# compiler options. If `runwasi` is non-empty then the test will be executed
# in that runner as well.
function(add_testcase runwasi test)
  foreach(target IN LISTS WASI_SDK_TARGETS)
    foreach(compile_flags IN LISTS opt_flags)
      # Mangle the options into something appropriate for a CMake rule name
      string(REGEX REPLACE " " "." target_name "${target}.${compile_flags}.${test}")

      # Add a new test executable based on `test`
      add_executable(${target_name} ${test})
      add_dependencies(build-tests ${target_name})

      # Configure all the compile options necessary. For example `--target` here
      # if the target doesn't look like it's already in the name of the compiler
      # as well.
      if(NOT(CMAKE_C_COMPILER MATCHES ${target}))
        target_compile_options(${target_name} PRIVATE --target=${target})
        target_link_options(${target_name} PRIVATE --target=${target})
      endif()

      # Apply test-specific compile options and link flags.
      if(test MATCHES "clocks.c$")
        target_compile_options(${target_name} PRIVATE -D_WASI_EMULATED_PROCESS_CLOCKS)
        target_link_options(${target_name} PRIVATE -lwasi-emulated-process-clocks)
      elseif(test MATCHES "mmap.c$")
        target_compile_options(${target_name} PRIVATE -D_WASI_EMULATED_MMAN)
        target_link_options(${target_name} PRIVATE -lwasi-emulated-mman)
      elseif(test MATCHES "(sigabrt|signals).c$")
        target_compile_options(${target_name} PRIVATE -D_WASI_EMULATED_SIGNAL)
        target_link_options(${target_name} PRIVATE -lwasi-emulated-signal)
      elseif(test MATCHES "printf-long-double-enabled.c$")
        target_link_options(${target_name} PRIVATE -lc-printscan-long-double)
      endif()

      # Apply language-specific options and dependencies.
      if(test MATCHES "cc$")
        target_compile_options(${target_name} PRIVATE -fno-exceptions)
        if(NOT WASI_SDK_TEST_HOST_TOOLCHAIN)
          add_dependencies(${target_name} libcxx-${target})
        endif()
      else()
        if(NOT WASI_SDK_TEST_HOST_TOOLCHAIN)
          add_dependencies(${target_name} wasi-libc-${target})
        endif()
      endif()

      # Apply target-specific options.
      if(target MATCHES threads)
        target_compile_options(${target_name} PRIVATE -pthread)
        target_link_options(${target_name} PRIVATE -pthread)
      endif()

      if(runwasi)
        add_test(
          NAME test-${target_name}
          COMMAND
            bash ../testcase.sh
            "${runwasi}"
            ${test}
            $<TARGET_FILE:${target_name}>
          WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
      endif()
    endforeach()
  endforeach()
endfunction()

add_subdirectory(compile-only)
add_subdirectory(general)

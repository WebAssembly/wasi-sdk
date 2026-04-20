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

# Registers `test` with CMake, compiling it with a number of flag combinations
# and for all enabled targets. This will register up to many tests with CTest.
#
# This function takes CMake-style arguments, specified as:
#
# * `EMULATED_CLOCKS` - enables `-lwasi-emulated-process-clocks` when compiling.
# * `EMULATED_MMAN` - enables `-lwasi-emulated-mman` when compiling.
# * `EMULATED_SIGNAL` - enables `-lwasi-emulated-signal` when compiling.
# * `PRINTSCAN_LONG_DOUBLE` - enables `-lc-printscan-long-double` when compiling.
# * `FSDIR` - requires `${test}.dir` to exist and mounts it when running the test
# * `PASS_REGULAR_EXPRESSION` - same as the CTest property
# * `ENV` - env vars (the `--env` flag in Wasmtime) to pass to the test.
# * `COMPILE_ONLY` - does not actually execute this test, just compiles it.
function(add_testcase test)
  set(options EMULATED_CLOCKS EMULATED_MMAN EMULATED_SIGNAL
    PRINTSCAN_LONG_DOUBLE FSDIR COMPILE_ONLY)
  set(oneValueArgs PASS_REGULAR_EXPRESSION)
  set(multiValueArgs ENV)
  cmake_parse_arguments(PARSE_ARGV 1 arg "${options}" "${oneValueArgs}" "${multiValueArgs}")

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
      if(${arg_EMULATED_CLOCKS})
        target_compile_options(${target_name} PRIVATE -D_WASI_EMULATED_PROCESS_CLOCKS)
        target_link_options(${target_name} PRIVATE -lwasi-emulated-process-clocks)
      endif()
      if(${arg_EMULATED_MMAN})
        target_compile_options(${target_name} PRIVATE -D_WASI_EMULATED_MMAN)
        target_link_options(${target_name} PRIVATE -lwasi-emulated-mman)
      endif()
      if(${arg_EMULATED_SIGNAL})
        target_compile_options(${target_name} PRIVATE -D_WASI_EMULATED_SIGNAL)
        target_link_options(${target_name} PRIVATE -lwasi-emulated-signal)
      endif()
      if(${arg_PRINTSCAN_LONG_DOUBLE})
        target_link_options(${target_name} PRIVATE -lc-printscan-long-double)
      endif()

      # Apply language-specific options and dependencies.
      if(test MATCHES "cc$")
        if(NOT (WASI_SDK_EXCEPTIONS STREQUAL "OFF"))
          target_compile_options(${target_name} PRIVATE -fwasm-exceptions -mllvm -wasm-use-legacy-eh=false)
          target_link_options(${target_name} PRIVATE -fwasm-exceptions -lunwind)
        else()
          target_compile_options(${target_name} PRIVATE -fno-exceptions)
        endif()
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

      if(target STREQUAL wasm32-wasi OR target STREQUAL wasm32-wasi-threads)
        target_compile_options(${target_name} PRIVATE -Wno-deprecated)
        target_link_options(${target_name} PRIVATE -Wno-deprecated)
      endif()

      if(arg_COMPILE_ONLY)
        continue()
      endif()

      set(runner ${WASI_SDK_RUNWASI})
      set(args)
      if(${runner} MATCHES wasmtime)
        if(target MATCHES threads)
          list(APPEND runner -Wshared-memory)
        endif()
        if(WASI_SDK_EXCEPTIONS)
          list(APPEND runner -Wexceptions)
        endif()
        if(target MATCHES "wasip3")
          list(APPEND runner -Wcomponent-model-async -Sp3)
        endif()
      endif()

      foreach(env IN LISTS arg_ENV)
        list(APPEND runner --env ${env})
      endforeach()

      if (${arg_FSDIR})
        list(APPEND runner --dir ${CMAKE_CURRENT_SOURCE_DIR}/${test}.dir::${test}.dir)
        list(APPEND args ${test}.dir)
      endif()

      add_test(
        NAME test-${target_name}
        COMMAND
          ${runner}
          $<TARGET_FILE:${target_name}>
          ${args}
      )
      if (arg_PASS_REGULAR_EXPRESSION)
        set_tests_properties(test-${target_name} PROPERTIES PASS_REGULAR_EXPRESSION ${arg_PASS_REGULAR_EXPRESSION})
      endif()
    endforeach()
  endforeach()
endfunction()

add_subdirectory(compile-only)
add_subdirectory(general)

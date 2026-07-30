# Support for running tests in the `tests/{compile-only,general}` folders
cmake_minimum_required(VERSION 3.22)

# Give access to `../src/wasi-libc/cmake` local folder for `include(...)`.
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../src/wasi-libc/cmake")

project(wasi-sdk-test)
include(CTest)
include(wasm-tools)
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

# TODO: This was copied from wasi-libc/CMakeLists.txt and should be factored out
# into its own file for reuse:
function(set_pic target)
  set_target_properties(${target} PROPERTIES POSITION_INDEPENDENT_CODE TRUE)
  # Windows needs an extra nudge to pass `-fPIC`
  if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
    target_compile_options(${target} PRIVATE -fPIC)
  endif()
endfunction()

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
    if(target MATCHES p1 OR NOT WASI_SDK_BUILD_SHARED)
      set(link_styles static)
    else()
      set(link_styles static shared)
    endif()

    foreach(compile_flags IN LISTS opt_flags)
      foreach(link_style IN LISTS link_styles)
        # Mangle the options into something appropriate for a CMake rule name
        string(REGEX REPLACE " " "." target_name "${target}.${compile_flags}.${link_style}.${test}")

        # Add a new test executable based on `test`
        add_executable(${target_name} ${test})
        add_dependencies(build-tests ${target_name})
        add_dependencies(${target_name} build)

        # Configure all the compile options necessary. For example `--target` here
        # if the target doesn't look like it's already in the name of the compiler
        # as well.
        if(NOT(CMAKE_C_COMPILER MATCHES ${target}))
          target_compile_options(${target_name} PRIVATE --target=${target})
          target_link_options(${target_name} PRIVATE --target=${target})
        endif()

        set(so_files "${wasi_sysroot}/lib/${target}/libc.so")

        # Apply test-specific compile options and link flags.
        if(${arg_EMULATED_CLOCKS})
          set(so_files ${so_files} "${wasi_sysroot}/lib/${target}/libwasi-emulated-process-clocks.so")
          target_compile_options(${target_name} PRIVATE -D_WASI_EMULATED_PROCESS_CLOCKS)
          target_link_options(${target_name} PRIVATE -lwasi-emulated-process-clocks)
        endif()
        if(${arg_EMULATED_MMAN})
          set(so_files ${so_files} "${wasi_sysroot}/lib/${target}/libwasi-emulated-mman.so")
          target_compile_options(${target_name} PRIVATE -D_WASI_EMULATED_MMAN)
          target_link_options(${target_name} PRIVATE -lwasi-emulated-mman)
        endif()
        if(${arg_EMULATED_SIGNAL})
          set(so_files ${so_files} "${wasi_sysroot}/lib/${target}/libwasi-emulated-signal.so")
          target_compile_options(${target_name} PRIVATE -D_WASI_EMULATED_SIGNAL)
          target_link_options(${target_name} PRIVATE -lwasi-emulated-signal)
        endif()
        if(${arg_PRINTSCAN_LONG_DOUBLE})
          target_link_options(${target_name} PRIVATE -lc-printscan-long-double)
        endif()

        # Apply language-specific options and dependencies.
        if(test MATCHES "cc$")
          if(WASI_SDK_EXCEPTIONS STREQUAL "DUAL")
            set(so_files ${so_files}
              "${wasi_sysroot}/lib/${target}/eh/libc++.so"
              "${wasi_sysroot}/lib/${target}/eh/libc++abi.so")
          else()
            set(so_files ${so_files}
              "${wasi_sysroot}/lib/${target}/libc++.so"
              "${wasi_sysroot}/lib/${target}/libc++abi.so")
          endif()

          if(NOT (WASI_SDK_EXCEPTIONS STREQUAL "OFF"))
            if(WASI_SDK_EXCEPTIONS STREQUAL "DUAL")
              set(so_files ${so_files} "${wasi_sysroot}/lib/${target}/eh/libunwind.so")
            else()
              set(so_files ${so_files} "${wasi_sysroot}/lib/${target}/libunwind.so")
            endif()

            target_compile_options(${target_name} PRIVATE -fwasm-exceptions -mllvm -wasm-use-legacy-eh=false)
            target_link_options(${target_name} PRIVATE -fwasm-exceptions)
            target_link_libraries(${target_name} unwind)
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

        if(link_style MATCHES shared)
          set_pic(${target_name})
          # Skip wit-component when linking to manually run `wasm-tools component
          # link` below. Additionally use `-shared` to wasm-ld, but notably not clang,
          # to get clang to work with this as an executable but get `wasm-ld` to
          # emit shared library imports.
          #
          # Note that `-fvisibility=default` is used to make the generated
          # `__main_void` symbol from clang visible to wasi-libc itself.
          target_link_options(${target_name} PRIVATE -Wl,--skip-wit-component,-shared)
          target_compile_options(${target_name} PRIVATE -fvisibility=default)
          add_custom_command(
            TARGET ${target_name}
            POST_BUILD
            COMMAND
              ${wasm_tools} component link
                ${so_files}
                $<TARGET_FILE:${target_name}>
                -o $<TARGET_FILE:${target_name}>
          )
          add_dependencies(${target_name} wasm-tools)
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
  endforeach()
endfunction()

add_subdirectory(compile-only)
add_subdirectory(general)

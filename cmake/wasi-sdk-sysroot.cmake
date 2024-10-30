# Build logic for building a sysroot for wasi-sdk which includes compiler-rt,
# wasi-libc, libcxx, and libcxxabi.

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE RelWithDebInfo)
endif()

if(NOT CMAKE_C_COMPILER_ID MATCHES Clang)
  message(FATAL_ERROR "C compiler ${CMAKE_C_COMPILER} is not `Clang`, it is ${CMAKE_C_COMPILER_ID}")
endif()

set(minimum_clang_required 18.0.0)

if(CMAKE_C_COMPILER_VERSION VERSION_LESS ${minimum_clang_required})
  message(FATAL_ERROR "compiler version ${CMAKE_C_COMPILER_VERSION} is less than the required version ${minimum_clang_required}")
endif()

message(STATUS "Found executable for `nm`: ${CMAKE_NM}")
message(STATUS "Found executable for `ar`: ${CMAKE_AR}")

find_program(MAKE make REQUIRED)

option(WASI_SDK_DEBUG_PREFIX_MAP "Pass `-fdebug-prefix-map` for built artifacts" ON)
option(WASI_SDK_INCLUDE_TESTS "Whether or not to build tests by default" OFF)
option(WASI_SDK_INSTALL_TO_CLANG_RESOURCE_DIR "Whether or not to modify the compiler's resource directory" OFF)
option(WASI_SDK_LTO "Whether or not to build LTO assets" ON)

set(wasi_tmp_install ${CMAKE_CURRENT_BINARY_DIR}/install)
set(wasi_sysroot ${wasi_tmp_install}/share/wasi-sysroot)
set(wasi_resource_dir ${wasi_tmp_install}/wasi-resource-dir)

if(WASI_SDK_DEBUG_PREFIX_MAP)
  add_compile_options(
    -fdebug-prefix-map=${CMAKE_CURRENT_SOURCE_DIR}=wasisdk://v${wasi_sdk_version})
endif()

# Default arguments for builds of cmake projects (mostly LLVM-based) to forward
# along much of our own configuration into these projects.
set(default_cmake_args
  -DCMAKE_SYSTEM_NAME=WASI
  -DCMAKE_SYSTEM_VERSION=1
  -DCMAKE_SYSTEM_PROCESSOR=wasm32
  -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
  -DCMAKE_AR=${CMAKE_AR}
  -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
  -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
  -DCMAKE_C_COMPILER_WORKS=ON
  -DCMAKE_CXX_COMPILER_WORKS=ON
  -DCMAKE_SYSROOT=${wasi_sysroot}
  -DCMAKE_MODULE_PATH=${CMAKE_CURRENT_SOURCE_DIR}/cmake)

if(CMAKE_C_COMPILER_LAUNCHER)
  list(APPEND default_cmake_args -DCMAKE_C_COMPILER_LAUNCHER=${CMAKE_C_COMPILER_LAUNCHER})
endif()
if(CMAKE_CXX_COMPILER_LAUNCHER)
  list(APPEND default_cmake_args -DCMAKE_CXX_COMPILER_LAUNCHER=${CMAKE_CXX_COMPILER_LAUNCHER})
endif()

# =============================================================================
# compiler-rt build logic
# =============================================================================

ExternalProject_Add(compiler-rt-build
  SOURCE_DIR "${llvm_proj_dir}/compiler-rt"
  CMAKE_ARGS
      ${default_cmake_args}
      -DCOMPILER_RT_BAREMETAL_BUILD=ON
      -DCOMPILER_RT_BUILD_XRAY=OFF
      -DCOMPILER_RT_INCLUDE_TESTS=OFF
      -DCOMPILER_RT_HAS_FPIC_FLAG=OFF
      -DCOMPILER_RT_ENABLE_IOS=OFF
      -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON
      -DCMAKE_C_COMPILER_TARGET=wasm32-wasi
      -DCOMPILER_RT_OS_DIR=wasi
      -DCMAKE_INSTALL_PREFIX=${wasi_resource_dir}
  EXCLUDE_FROM_ALL ON
  USES_TERMINAL_CONFIGURE ON
  USES_TERMINAL_BUILD ON
  USES_TERMINAL_INSTALL ON
)

# In addition to the default installation of `compiler-rt` itself also copy
# around some headers and make copies of the `wasi` directory as `wasip1` and
# `wasip2`
execute_process(
  COMMAND ${CMAKE_C_COMPILER} -print-resource-dir
  OUTPUT_VARIABLE clang_resource_dir
  OUTPUT_STRIP_TRAILING_WHITESPACE)
add_custom_target(compiler-rt-post-build
  # The `${wasi_resource_dir}` folder is going to get used as `-resource-dir`
  # for future compiles. Copy the host compiler's own headers into this
  # directory to ensure that all host-defined headers all work as well.
  COMMAND ${CMAKE_COMMAND} -E copy_directory
    ${clang_resource_dir}/include ${wasi_resource_dir}/include

  # Copy the `lib/wasi` folder to `libc/wasi{p1,p2}` to ensure that those
  # OS-strings also work for looking up the compiler-rt.a file.
  COMMAND ${CMAKE_COMMAND} -E copy_directory
    ${wasi_resource_dir}/lib/wasi ${wasi_resource_dir}/lib/wasip1
  COMMAND ${CMAKE_COMMAND} -E copy_directory
    ${wasi_resource_dir}/lib/wasi ${wasi_resource_dir}/lib/wasip2

  COMMENT "finalizing compiler-rt installation"
)
add_dependencies(compiler-rt-post-build compiler-rt-build)

add_custom_target(compiler-rt DEPENDS compiler-rt-build compiler-rt-post-build)


# =============================================================================
# wasi-libc build logic
# =============================================================================

function(define_wasi_libc_sub target target_suffix lto)
  set(build_dir ${CMAKE_CURRENT_BINARY_DIR}/wasi-libc-${target}${target_suffix})

  if(${target} MATCHES threads)
    if(lto)
      set(extra_make_flags LTO=full THREAD_MODEL=posix)
    else()
      set(extra_make_flags THREAD_MODEL=posix)
    endif()
  elseif(${target} MATCHES p2)
    if(lto)
      set(extra_make_flags LTO=full WASI_SNAPSHOT=p2 default)
    else()
      set(extra_make_flags WASI_SNAPSHOT=p2 default libc_so)
    endif()
  else()
    if(lto)
      set(extra_make_flags LTO=full default)
    else()
      set(extra_make_flags default libc_so)
    endif()
  endif()

  string(TOUPPER ${CMAKE_BUILD_TYPE} CMAKE_BUILD_TYPE_UPPER)
  get_property(directory_cflags DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY COMPILE_OPTIONS)
  list(APPEND directory_cflags -resource-dir ${wasi_resource_dir})
  set(extra_cflags_list
    "${CMAKE_C_FLAGS} ${directory_cflags} ${CMAKE_C_FLAGS_${CMAKE_BUILD_TYPE_UPPER}}")
  list(JOIN extra_cflags_list " " extra_cflags)

  ExternalProject_Add(wasi-libc-${target}${target_suffix}-build
    # Currently wasi-libc doesn't support out-of-tree builds so feign a
    # "download command" which copies the source tree to a different location
    # so out-of-tree builds are supported.
    DOWNLOAD_COMMAND
      ${CMAKE_COMMAND} -E copy_directory ${wasi_libc} ${build_dir}
    SOURCE_DIR "${build_dir}"
    CONFIGURE_COMMAND ""
    BUILD_COMMAND
      ${MAKE} -j8 -C ${build_dir}
        CC=${CMAKE_C_COMPILER}
        AR=${CMAKE_AR}
        NM=${CMAKE_NM}
        SYSROOT=${wasi_sysroot}
        EXTRA_CFLAGS=${extra_cflags}
        TARGET_TRIPLE=${target}
        ${extra_make_flags}
    INSTALL_COMMAND ""
    DEPENDS compiler-rt
    EXCLUDE_FROM_ALL ON
    USES_TERMINAL_CONFIGURE ON
    USES_TERMINAL_BUILD ON
    USES_TERMINAL_INSTALL ON
  )
endfunction()

function(define_wasi_libc target)
  define_wasi_libc_sub (${target} "" OFF)
  if(WASI_SDK_LTO)
    define_wasi_libc_sub (${target} "-lto" ON)
  endif()

  add_custom_target(wasi-libc-${target}
    DEPENDS wasi-libc-${target}-build $<$<BOOL:${WASI_SDK_LTO}>:wasi-libc-${target}-lto-build>)
endfunction()

foreach(target IN LISTS WASI_SDK_TARGETS)
  define_wasi_libc(${target})
endforeach()

# =============================================================================
# libcxx build logic
# =============================================================================

execute_process(
  COMMAND ${CMAKE_C_COMPILER} -dumpversion
  OUTPUT_VARIABLE llvm_version
  OUTPUT_STRIP_TRAILING_WHITESPACE)

function(define_libcxx_sub target target_suffix extra_target_flags extra_libdir_suffix)
  if(${target} MATCHES threads)
    set(pic OFF)
    set(target_flags -pthread)
  else()
    set(pic ON)
    set(target_flags -D_WASI_EMULATED_PTHREAD)
  endif()
  if(${target_suffix} MATCHES lto)
    set(pic OFF)
  endif()
  list(APPEND target_flags ${extra_target_flags})

  set(runtimes "libcxx;libcxxabi")

  get_property(dir_compile_opts DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY COMPILE_OPTIONS)
  get_property(dir_link_opts DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY LINK_OPTIONS)
  set(extra_flags
    ${target_flags}
    --target=${target}
    ${dir_compile_opts}
    ${dir_link_opts}
    --sysroot ${wasi_sysroot}
    -resource-dir ${wasi_resource_dir})

  set(extra_cflags_list ${CMAKE_C_FLAGS} ${extra_flags})
  list(JOIN extra_cflags_list " " extra_cflags)
  set(extra_cxxflags_list ${CMAKE_CXX_FLAGS} ${extra_flags})
  list(JOIN extra_cxxflags_list " " extra_cxxflags)

  ExternalProject_Add(libcxx-${target}${target_suffix}-build
    SOURCE_DIR ${llvm_proj_dir}/runtimes
    CMAKE_ARGS
      ${default_cmake_args}
      # Ensure headers are installed in a target-specific path instead of a
      # target-generic path.
      -DCMAKE_INSTALL_INCLUDEDIR=${wasi_sysroot}/include/${target}
      -DCMAKE_STAGING_PREFIX=${wasi_sysroot}
      -DCMAKE_POSITION_INDEPENDENT_CODE=${pic}
      -DCXX_SUPPORTS_CXX11=ON
      -DLIBCXX_ENABLE_THREADS:BOOL=ON
      -DLIBCXX_HAS_PTHREAD_API:BOOL=ON
      -DLIBCXX_HAS_EXTERNAL_THREAD_API:BOOL=OFF
      -DLIBCXX_BUILD_EXTERNAL_THREAD_LIBRARY:BOOL=OFF
      -DLIBCXX_HAS_WIN32_THREAD_API:BOOL=OFF
      -DLLVM_COMPILER_CHECKED=ON
      -DLIBCXX_ENABLE_SHARED:BOOL=${pic}
      -DLIBCXX_ENABLE_EXPERIMENTAL_LIBRARY:BOOL=OFF
      -DLIBCXX_ENABLE_EXCEPTIONS:BOOL=OFF
      -DLIBCXX_ENABLE_FILESYSTEM:BOOL=ON
      -DLIBCXX_ENABLE_ABI_LINKER_SCRIPT:BOOL=OFF
      -DLIBCXX_CXX_ABI=libcxxabi
      -DLIBCXX_CXX_ABI_INCLUDE_PATHS=${llvm_proj_dir}/libcxxabi/include
      -DLIBCXX_HAS_MUSL_LIBC:BOOL=ON
      -DLIBCXX_ABI_VERSION=2
      -DLIBCXXABI_ENABLE_EXCEPTIONS:BOOL=OFF
      -DLIBCXXABI_ENABLE_SHARED:BOOL=${pic}
      -DLIBCXXABI_SILENT_TERMINATE:BOOL=ON
      -DLIBCXXABI_ENABLE_THREADS:BOOL=ON
      -DLIBCXXABI_HAS_PTHREAD_API:BOOL=ON
      -DLIBCXXABI_HAS_EXTERNAL_THREAD_API:BOOL=OFF
      -DLIBCXXABI_BUILD_EXTERNAL_THREAD_LIBRARY:BOOL=OFF
      -DLIBCXXABI_HAS_WIN32_THREAD_API:BOOL=OFF
      -DLIBCXXABI_ENABLE_PIC:BOOL=${pic}
      -DLIBCXXABI_USE_LLVM_UNWINDER:BOOL=OFF
      -DUNIX:BOOL=ON
      -DCMAKE_C_FLAGS=${extra_cflags}
      -DCMAKE_CXX_FLAGS=${extra_cxxflags}
      -DLIBCXX_LIBDIR_SUFFIX=/${target}${extra_libdir_suffix}
      -DLIBCXXABI_LIBDIR_SUFFIX=/${target}${extra_libdir_suffix}
      -DLIBCXX_INCLUDE_TESTS=OFF
      -DLIBCXX_INCLUDE_BENCHMARKS=OFF

    # See https://www.scivision.dev/cmake-externalproject-list-arguments/ for
    # why this is in `CMAKE_CACHE_ARGS` instead of above
    CMAKE_CACHE_ARGS
      -DLLVM_ENABLE_RUNTIMES:STRING=${runtimes}
    DEPENDS
      wasi-libc-${target}
      compiler-rt
    EXCLUDE_FROM_ALL ON
    USES_TERMINAL_CONFIGURE ON
    USES_TERMINAL_BUILD ON
    USES_TERMINAL_INSTALL ON
  )
endfunction()

function(define_libcxx target)
  define_libcxx_sub(${target} "" "" "")
  if(WASI_SDK_LTO)
    # Note: clang knows this /llvm-lto/${llvm_version} convention.
    # https://github.com/llvm/llvm-project/blob/llvmorg-18.1.8/clang/lib/Driver/ToolChains/WebAssembly.cpp#L204-L210
    define_libcxx_sub(${target} "-lto" "-flto=full" "/llvm-lto/${llvm_version}")
  endif()

  # As of this writing, `clang++` will ignore the target-specific include dirs
  # unless this one also exists:
  add_custom_target(libcxx-${target}-extra-dir
    COMMAND ${CMAKE_COMMAND} -E make_directory ${wasi_sysroot}/include/c++/v1
    COMMENT "creating libcxx-specific header file folder")
  add_custom_target(libcxx-${target}
    DEPENDS libcxx-${target}-build $<$<BOOL:${WASI_SDK_LTO}>:libcxx-${target}-lto-build> libcxx-${target}-extra-dir)
endfunction()

foreach(target IN LISTS WASI_SDK_TARGETS)
  define_libcxx(${target})
endforeach()

# =============================================================================
# misc build logic
# =============================================================================

install(DIRECTORY ${wasi_tmp_install}/share
        USE_SOURCE_PERMISSIONS
        DESTINATION ${CMAKE_INSTALL_PREFIX})
if(WASI_SDK_INSTALL_TO_CLANG_RESOURCE_DIR)
  install(DIRECTORY ${wasi_resource_dir}/lib
          USE_SOURCE_PERMISSIONS
          DESTINATION ${clang_resource_dir})
else()
  install(DIRECTORY ${wasi_resource_dir}/lib
          USE_SOURCE_PERMISSIONS
          DESTINATION ${CMAKE_INSTALL_PREFIX}/clang-resource-dir)
endif()

# Add a top-level `build` target as well as `build-$target` targets.
add_custom_target(build ALL)
foreach(target IN LISTS WASI_SDK_TARGETS)
  add_custom_target(build-${target})
  add_dependencies(build-${target} libcxx-${target} wasi-libc-${target} compiler-rt)
  add_dependencies(build build-${target})
endforeach()

# Install a `VERSION` file in the output prefix with a dump of version
# information.
execute_process(
  COMMAND ${PYTHON} ${version_script} dump
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  OUTPUT_VARIABLE version_dump)
set(version_file_tmp ${wasi_sysroot}/VERSION)
file(GENERATE OUTPUT ${version_file_tmp} CONTENT ${version_dump})
add_custom_target(version-file DEPENDS ${version_file_tmp})
add_dependencies(build version-file)

if(WASI_SDK_INCLUDE_TESTS)
  add_subdirectory(tests)
endif()

include(wasi-sdk-dist)

set(dist_dir ${CMAKE_CURRENT_BINARY_DIR}/dist)

# Tarball with just `compiler-rt` builtins within it
wasi_sdk_add_tarball(dist-compiler-rt
  ${dist_dir}/libclang_rt.builtins-wasm32-wasi-${wasi_sdk_version}.tar.gz
  ${wasi_resource_dir}/lib/wasi)
add_dependencies(dist-compiler-rt compiler-rt)

# Tarball with the whole sysroot
wasi_sdk_add_tarball(dist-sysroot
  ${dist_dir}/wasi-sysroot-${wasi_sdk_version}.tar.gz
  ${wasi_sysroot})
add_dependencies(dist-sysroot build)

add_custom_target(dist DEPENDS dist-compiler-rt dist-sysroot)

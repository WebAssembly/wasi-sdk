# Build logic and support for building a Clang toolchain that can target
# WebAssembly and build a WASI sysroot.

set(LLVM_CMAKE_FLAGS "" CACHE STRING "Extra cmake flags to pass to LLVM's build")
set(RUST_TARGET "" CACHE STRING "Target to build Rust code for, if not the host")
set(WASI_SDK_ARTIFACT "" CACHE STRING "Name of the wasi-sdk artifact being produced")

option(WASI_SDK_LLDB "Include a build of LLDB" ON)

set(LIBEDIT_DEFAULT ON)
# I don't want to deal with running a `./configure` script on Windows, disable
# it by default.
if(WIN32)
  set(LIBEDIT_DEFAULT OFF)
endif()
# I don't know how to resolve build failures when building libedit for x86_64
# from arm64 on macos, so disable it for now.
if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm64" AND LLVM_CMAKE_FLAGS MATCHES "x86_64")
  set(LIBEDIT_DEFAULT OFF)
endif()
option(WASI_SDK_LIBEDIT "Whether or not to build libedit for LLDB" ${LIBEDIT_DEFAULT})
option(WASI_SDK_LIBXML2 "Whether or not to build libxml2 for LLDB" ON)

string(REGEX REPLACE "[ ]+" ";" llvm_cmake_flags_list "${LLVM_CMAKE_FLAGS}")

set(wasi_tmp_install ${CMAKE_CURRENT_BINARY_DIR}/install)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE MinSizeRel)
endif()

set(default_cmake_args
  -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
  -DCMAKE_AR=${CMAKE_AR}
  -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
  -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
  -DCMAKE_INSTALL_PREFIX=${wasi_tmp_install})

if(CMAKE_C_COMPILER_LAUNCHER)
  list(APPEND default_cmake_args -DCMAKE_C_COMPILER_LAUNCHER=${CMAKE_C_COMPILER_LAUNCHER})
endif()
if(CMAKE_CXX_COMPILER_LAUNCHER)
  list(APPEND default_cmake_args -DCMAKE_CXX_COMPILER_LAUNCHER=${CMAKE_CXX_COMPILER_LAUNCHER})
endif()

set(links_to_create clang-cl clang-cpp clang++)
foreach(target IN LISTS WASI_SDK_TARGETS)
  list(APPEND links_to_create ${target}-clang)
  list(APPEND links_to_create ${target}-clang++)
endforeach()

set(projects "lld;clang;clang-tools-extra")

set(tools
  clang
  clang-format
  clang-tidy
  clang-apply-replacements
  lld
  llvm-addr2line
  llvm-mc
  llvm-ranlib
  llvm-strip
  llvm-dwarfdump
  llvm-dwp
  clang-resource-headers
  ar
  ranlib
  strip
  nm
  size
  strings
  objdump
  objcopy
  c++filt
  llvm-config
  libclang)

# By default link LLVM dynamically to all the various tools. This greatly
# reduces the binary size of all the tools through a shared library rather than
# statically linking LLVM to each individual tool. This requires a few other
# install targets as well to ensure the appropriate libraries are all installed.
#
# Also note that the `-wasi-sdk` version suffix is intended to help prevent
# these dynamic libraries from clashing with other system libraries in case the
# `lib` dir gets put on `LD_LIBRARY_PATH` or similar.
if(NOT WIN32)
  list(APPEND default_cmake_args -DLLVM_LINK_LLVM_DYLIB=ON -DLLVM_VERSION_SUFFIX=-wasi-sdk)
  list(APPEND tools LLVM clang-cpp)
endif()

# Configure/add LLDB if requested.
#
# Note that LLDB depends on `libedit` which is more-or-less required to get a
# reasonable command-line experience, so this is built custom here to ensure
# that it's available for LLDB.
if(WASI_SDK_LLDB)
  list(APPEND projects lldb)
  list(APPEND tools lldb liblldb)
  list(APPEND default_cmake_args
    -DLLDB_INCLUDE_TESTS=OFF
    -DLLDB_INCLUDE_UNITTESTS=OFF
    -DLLDB_ENABLE_SWIG=OFF
    -DLLDB_ENABLE_CURSES=OFF
    -DLLDB_ENABLE_LZMA=OFF
    -DLLDB_ENABLE_LUA=OFF
    -DLLDB_ENABLE_PYTHON=OFF
    -DLLDB_ENABLE_FBSDVMCORE=OFF
    -DLLDB_ENABLE_LINUXPTY=OFF
  )

  set(extra_configure_commands)
  if(CMAKE_SYSTEM_NAME STREQUAL Linux)
    set(extra_configure_commands
      # By default it looks like `libedit` tries to link to `libncurses.so` and
      # such on Linux. This is problematic as systems may not have that
      # installed. Turns out though at least for AlmaLinux [1] they just edit
      # makefile and pkg-config info and it works out. Who knew! I thought
      # one of the millions of lines in `./configure` would take care of this
      # but apparently we're still resorting to editing things raw...
      #
      # [1]: https://git.almalinux.org/rpms/libedit/src/commit/3f0893c4cd8e0cbb2f556d2fad48326c9c037a6c/SPECS/libedit.spec#L44-L48
      COMMAND sed -i "s/lncurses/ltinfo/" src/Makefile
      COMMAND sed -i "s/ -lncurses//" libedit.pc
    )
  endif()

  if (WASI_SDK_LIBEDIT)
    include(ProcessorCount)
    ProcessorCount(nproc)
    find_program(MAKE_EXECUTABLE make REQUIRED)
    if(CMAKE_SYSTEM_NAME STREQUAL Darwin)
      set(libedit_ldflags -Wl,-install_name,@rpath/libedit.0.dylib)
    endif()
    ExternalProject_Add(libedit
      URL https://thrysoee.dk/editline/libedit-20251016-3.1.tar.gz
      URL_HASH SHA256=21362b00653bbfc1c71f71a7578da66b5b5203559d43134d2dd7719e313ce041

      # Without this the build system tries to find and use `aclocal-1.18` where
      # with this it doesn't so turn this on.
      DOWNLOAD_EXTRACT_TIMESTAMP ON

      CONFIGURE_COMMAND
        <SOURCE_DIR>/configure
          --prefix=${wasi_tmp_install}
          --enable-pic
          --disable-examples
          --disable-static
          --disable-silent-rules
          CC=${CMAKE_C_COMPILER}
          LDFLAGS=${libedit_ldflags}
      ${extra_configure_commands}
      BUILD_COMMAND
        ${MAKE_EXECUTABLE} -j${nproc}

      USES_TERMINAL_CONFIGURE ON
      USES_TERMINAL_BUILD ON
      USES_TERMINAL_INSTALL ON
    )
    list(APPEND default_cmake_args
      -DLLDB_ENABLE_LIBEDIT=ON
      -DLibEdit_ROOT=${wasi_tmp_install}
    )
  else()
    list(APPEND default_cmake_args -DLLDB_ENABLE_LIBEDIT=OFF)
    add_custom_target(libedit)
  endif()

  set(libxml_cmake_args)

  # Windows doesn't have iconv by default, so disable it for now.
  if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
    list(APPEND libxml_cmake_args -DLIBXML2_WITH_ICONV=OFF)
  endif()

  # Our AlmaLinux:8 container ends up using `lib64` instead of `lib` by default
  # which doesn't match LLVM, so specifically use the same dir as LLVM.
  if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
    list(APPEND libxml_cmake_args -DCMAKE_INSTALL_LIBDIR=lib)
  endif()

  if (WASI_SDK_LIBXML2)
    ExternalProject_Add(libxml2
      URL https://download.gnome.org/sources/libxml2/2.15/libxml2-2.15.2.tar.xz
      URL_HASH SHA256=c8b9bc81f8b590c33af8cc6c336dbff2f53409973588a351c95f1c621b13d09d

      CMAKE_ARGS
        ${default_cmake_args}
        -DLIBXML2_WITH_PROGRAMS=OFF
        -DLIBXML2_WITH_DEBUG=OFF
        -DLIBXML2_WITH_DOCS=OFF
        -DLIBXML2_WITH_TESTS=OFF
        ${libxml_cmake_args}
        ${llvm_cmake_flags_list}

      USES_TERMINAL_CONFIGURE ON
      USES_TERMINAL_BUILD ON
      USES_TERMINAL_INSTALL ON
    )
    list(APPEND default_cmake_args
      -DLLDB_ENABLE_LIBXML2=ON
      -DLibXml2_ROOT=${wasi_tmp_install}
    )
  else()
    list(APPEND default_cmake_args -DLLDB_ENABLE_LIBXML2=OFF)
    add_custom_target(libxml2)
  endif()
else()
  add_custom_target(libedit)
  add_custom_target(libxml2)
endif()

list(TRANSFORM tools PREPEND --target= OUTPUT_VARIABLE build_targets)
list(TRANSFORM tools PREPEND --target=install- OUTPUT_VARIABLE install_targets)

ExternalProject_Add(llvm-build
  SOURCE_DIR "${llvm_proj_dir}/llvm"
  CMAKE_ARGS
    ${default_cmake_args}
    -DLLVM_ENABLE_ZLIB=OFF
    -DLLVM_ENABLE_ZSTD=OFF
    -DLLVM_STATIC_LINK_CXX_STDLIB=ON
    -DLLVM_INCLUDE_TESTS=OFF
    -DLLVM_INCLUDE_UTILS=OFF
    -DLLVM_INCLUDE_BENCHMARKS=OFF
    -DLLVM_INCLUDE_EXAMPLES=OFF
    -DLLVM_TARGETS_TO_BUILD=WebAssembly
    -DLLVM_DEFAULT_TARGET_TRIPLE=wasm32-wasip1
    -DLLVM_INSTALL_BINUTILS_SYMLINKS=TRUE
    -DLLVM_ENABLE_LIBXML2=OFF
    # Pass `-s` to strip symbols by default and shrink the size of the
    # distribution
    -DCMAKE_EXE_LINKER_FLAGS=-s
    # Looks to be required on macOS for, at build time, the dynamic linker to
    # find `libedit.dylib` when that's enabled.
    -DCMAKE_BUILD_RPATH=${wasi_tmp_install}/lib
    ${llvm_cmake_flags_list}
  # See https://www.scivision.dev/cmake-externalproject-list-arguments/ for
  # why this is in `CMAKE_CACHE_ARGS` instead of above
  CMAKE_CACHE_ARGS
    -DLLVM_ENABLE_PROJECTS:STRING=${projects}
    -DCLANG_LINKS_TO_CREATE:STRING=${links_to_create}
  BUILD_COMMAND
    cmake --build . ${build_targets}
  INSTALL_COMMAND
    cmake --build . ${install_targets}
  USES_TERMINAL_CONFIGURE ON
  USES_TERMINAL_BUILD ON
  USES_TERMINAL_INSTALL ON
)

add_custom_target(build ALL DEPENDS llvm-build)
ExternalProject_Add_StepDependencies(llvm-build configure libedit libxml2)

# Installation target for this outer project for installing the toolchain to the
# system.
install(DIRECTORY ${wasi_tmp_install}/bin ${wasi_tmp_install}/lib ${wasi_tmp_install}/share
        USE_SOURCE_PERMISSIONS
        DESTINATION ${CMAKE_INSTALL_PREFIX})

# Build logic for `wasm-component-ld` installed from Rust code.
set(wasm_component_ld_root ${CMAKE_CURRENT_BINARY_DIR}/wasm-component-ld)
set(wasm_component_ld ${wasm_component_ld_root}/bin/wasm-component-ld${CMAKE_EXECUTABLE_SUFFIX})
set(wasm_component_ld_version 0.5.22)
if(RUST_TARGET)
  set(rust_target_flag --target=${RUST_TARGET})
endif()
add_custom_command(
  OUTPUT ${wasm_component_ld}
  COMMAND
    cargo install --root ${wasm_component_ld_root} ${rust_target_flag}
      wasm-component-ld@${wasm_component_ld_version}
  COMMAND
    cmake -E make_directory ${wasi_tmp_install}/bin
  COMMAND
    cmake -E copy ${wasm_component_ld} ${wasi_tmp_install}/bin
  COMMENT "Building `wasm-component-ld` ...")
add_custom_target(wasm-component-ld DEPENDS ${wasm_component_ld})
add_dependencies(build wasm-component-ld)

# Setup installation logic for CMake support files.
add_custom_target(misc-files)
add_dependencies(build misc-files)

function(copy_misc_file src dst_folder)
  cmake_path(GET src FILENAME src_filename)
  set(dst ${wasi_tmp_install}/share/${dst_folder}/${src_filename})
  add_custom_command(
    OUTPUT ${dst}
    COMMAND cmake -E copy ${CMAKE_CURRENT_SOURCE_DIR}/${src} ${dst})
  add_custom_target(copy-${src_filename} DEPENDS ${dst})
  add_dependencies(misc-files copy-${src_filename})
endfunction()

copy_misc_file(src/config/config.sub misc)
copy_misc_file(src/config/config.guess misc)
copy_misc_file(wasi-sdk.cmake cmake)
copy_misc_file(wasi-sdk-pthread.cmake cmake)
copy_misc_file(wasi-sdk-p1.cmake cmake)
copy_misc_file(wasi-sdk-p2.cmake cmake)
copy_misc_file(wasi-sdk-p3.cmake cmake)
copy_misc_file(cmake/Platform/WASI.cmake cmake/Platform)

function(copy_cfg_file compiler)
  set(dst ${wasi_tmp_install}/bin/${compiler}.cfg)
  add_custom_command(
    OUTPUT ${dst}
    COMMAND cmake -E copy ${CMAKE_CURRENT_SOURCE_DIR}/clang.cfg ${dst})
  add_custom_target(copy-${compiler} DEPENDS ${dst})
  add_dependencies(misc-files copy-${compiler})
endfunction()

copy_cfg_file(clang)
copy_cfg_file(clang++)

include(wasi-sdk-dist)

# Figure out the name of the artifact which is either explicitly specified or
# inferred from CMake default variables.
if(WASI_SDK_ARTIFACT)
  set(wasi_sdk_artifact ${WASI_SDK_ARTIFACT})
else()
  if(APPLE)
    set(wasi_sdk_os macos)
  else()
    string(TOLOWER ${CMAKE_SYSTEM_NAME} wasi_sdk_os)
  endif()
  set(wasi_sdk_arch ${CMAKE_SYSTEM_PROCESSOR})
  set(wasi_sdk_artifact ${wasi_sdk_arch}-${wasi_sdk_os})
endif()

set(dist_dir ${CMAKE_CURRENT_BINARY_DIR}/dist)
wasi_sdk_add_tarball(dist-toolchain
  ${dist_dir}/wasi-toolchain-${wasi_sdk_version}-${wasi_sdk_artifact}.tar.gz
  ${wasi_tmp_install})
add_dependencies(dist-toolchain build)
add_custom_target(dist DEPENDS dist-toolchain)

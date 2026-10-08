# Cmake toolchain description file for the Makefile

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}")

set(CMAKE_SYSTEM_NAME WEB)
set(CMAKE_SYSTEM_VERSION 1)
set(CMAKE_SYSTEM_PROCESSOR wasm32)
set(CMAKE_EXECUTABLE_SUFFIX .wasm)
set(triple wasm32-webp2)

if(WIN32)
	set(HOST_EXE_SUFFIX ".exe")
else()
	set(HOST_EXE_SUFFIX "")
endif()

# When building from source, WEB_SDK_PREFIX represents the generated directory
if(NOT WEB_SDK_PREFIX)
	set(WEB_SDK_PREFIX ${CMAKE_CURRENT_LIST_DIR}/../../)
endif()

set(CMAKE_C_COMPILER ${WEB_SDK_PREFIX}/bin/clang${HOST_EXE_SUFFIX})
set(CMAKE_CXX_COMPILER ${WEB_SDK_PREFIX}/bin/clang++${HOST_EXE_SUFFIX})
set(CMAKE_ASM_COMPILER ${WEB_SDK_PREFIX}/bin/clang${HOST_EXE_SUFFIX})
set(CMAKE_AR ${WEB_SDK_PREFIX}/bin/llvm-ar${HOST_EXE_SUFFIX})
set(CMAKE_RANLIB ${WEB_SDK_PREFIX}/bin/llvm-ranlib${HOST_EXE_SUFFIX})
set(CMAKE_C_COMPILER_TARGET ${triple})
set(CMAKE_CXX_COMPILER_TARGET ${triple})
set(CMAKE_ASM_COMPILER_TARGET ${triple})

# Don't look in the sysroot for executables to run during the build
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
# Only look in the sysroot (not in the host paths) for the rest
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

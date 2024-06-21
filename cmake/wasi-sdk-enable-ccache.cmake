# Helper module to auto-enable ccache if detected.

find_program(CCACHE ccache)

option(WASI_SDK_DISABLE_CCACHE "Force disable ccache even if it's found" OFF)

if(NOT CMAKE_C_COMPILER_LAUNCHER)
  if(NOT WASI_SDK_DISABLE_CCACHE)
    if(CCACHE)
      set(CMAKE_C_COMPILER_LAUNCHER ccache)
      set(CMAKE_CXX_COMPILER_LAUNCHER ccache)
      message(STATUS "Auto-enabling ccache")
    else()
      message(STATUS "Failed to auto-enable ccache, not found on system")
    endif()
  endif()
endif()

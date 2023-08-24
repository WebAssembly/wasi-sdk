cmake_minimum_required(VERSION 3.22)

project(wasi-sdk-test)

# Sanity check setup
if (NOT ${CMAKE_SYSTEM_NAME} STREQUAL WASI)
    message(FATAL_ERROR "Wrong system name (${CMAKE_SYSTEM_NAME}), wrong toolchain file in use?")
endif()

if(NOT DEFINED WASI)
    message(FATAL_ERROR "WASI is not set, platform file likely not loaded")
endif()

set(RUNWASI "" CACHE STRING "Path to or name of WASM runner")

# Test build a C and C++ target respectively
add_executable(void_main_c ../general/void_main.c)
add_executable(void_main_cc ../general/void_main.cc)

include(CTest)
enable_testing()

add_test(NAME void_main_c
    COMMAND
        ${CMAKE_CURRENT_SOURCE_DIR}/test_driver.sh
        ${RUNWASI}
        $<TARGET_FILE:void_main_c>
        ${CMAKE_CURRENT_SOURCE_DIR}/../general/void_main.c.stdout.expected)
add_test(NAME void_main_cc
    COMMAND
        ${CMAKE_CURRENT_SOURCE_DIR}/test_driver.sh
        ${RUNWASI}
        $<TARGET_FILE:void_main_cc>
        ${CMAKE_CURRENT_SOURCE_DIR}/../general/void_main.cc.stdout.expected)

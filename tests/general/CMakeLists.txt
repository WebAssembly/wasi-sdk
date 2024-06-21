file(GLOB c_general_tests RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "*.c")
file(GLOB cxx_general_tests RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "*.cc")

set(general_tests ${c_general_tests} ${cxx_general_tests})

foreach(test IN LISTS general_tests)
  add_testcase(${WASI_SDK_RUNWASI} ${test})
endforeach()

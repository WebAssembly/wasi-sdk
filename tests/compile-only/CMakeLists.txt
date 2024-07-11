file(GLOB c_compile_tests RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "*.c")
file(GLOB cxx_compile_tests RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "*.cc")

set(compile_tests ${c_compile_tests} ${cxx_compile_tests})

foreach(test IN LISTS compile_tests)
  add_testcase("" ${test})
endforeach()


# Helper function to create tarballs for wasi-sdk.
#
# The `target` is the name of the CMake target to create for the creation of
# this tarball. The `tarball` argument is where the final tarball will be
# located. The name of the tarball is also used for the name of the root folder
# in the tarball. The `dir` argument is is the directory that will get packaged
# up within the tarball.
function(wasi_sdk_add_tarball target tarball dir)
  cmake_path(GET tarball PARENT_PATH tarball_dir)

  # Run STEM twice to chop of both `.gz` and `.tar` in `.tar.gz`
  cmake_path(GET tarball STEM LAST_ONLY tarball_stem)
  cmake_path(GET tarball_stem STEM LAST_ONLY tarball_stem)

  if(CMAKE_SYSTEM_NAME MATCHES Windows)
    # Copy the contents of symlinks on Windows to avoid dealing with symlink
    set(copy_dir ${CMAKE_COMMAND} -E copy_directory ${dir} ${tarball_stem})
  else()
    # ... but on non-Windows copy symlinks themselves to cut down on
    # distribution size.
    set(copy_dir cp -R ${dir} ${tarball_stem})
  endif()

  add_custom_command(
    OUTPUT ${tarball}
    # First copy the directory under a different name, the filestem of the
    # tarball.
    COMMAND ${copy_dir}
    # Next use CMake to create the tarball itself
    COMMAND ${CMAKE_COMMAND} -E tar cfz ${tarball} ${tarball_stem}
    # Finally delete the temporary directory created above.
    COMMAND ${CMAKE_COMMAND} -E rm -rf ${tarball_stem}
    WORKING_DIRECTORY ${tarball_dir}
    COMMENT "Creating ${tarball}..."
  )
  add_custom_target(${target} DEPENDS ${tarball})
endfunction()

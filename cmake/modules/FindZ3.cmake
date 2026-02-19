# FindZ3.cmake - Find Z3 SMT solver via pkg-config
# Sets: Z3_FOUND, Z3_INCLUDE_DIRS, Z3_LIBRARIES, z3::libz3 (imported target)

find_package(PkgConfig QUIET)
pkg_check_modules(PC_Z3 QUIET z3)

find_path(Z3_INCLUDE_DIR z3.h HINTS ${PC_Z3_INCLUDE_DIRS})
find_library(Z3_LIBRARY NAMES z3 HINTS ${PC_Z3_LIBRARY_DIRS})

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Z3 DEFAULT_MSG Z3_LIBRARY Z3_INCLUDE_DIR)

if(Z3_FOUND AND NOT TARGET z3::libz3)
    add_library(z3::libz3 UNKNOWN IMPORTED)
    set_target_properties(z3::libz3 PROPERTIES
        IMPORTED_LOCATION "${Z3_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${Z3_INCLUDE_DIR}"
    )
endif()

mark_as_advanced(Z3_INCLUDE_DIR Z3_LIBRARY)

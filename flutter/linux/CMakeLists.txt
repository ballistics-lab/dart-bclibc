# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.13)

set(PROJECT_NAME "dart_bclibc")
project(${PROJECT_NAME} LANGUAGES C CXX)

set(BCLIBC_VERSION "950c2e5eedd3a5e74a53532ba535011526130b62")

# ============================================================================
# dart_bclibc – thin C wrapper over the embedded bclibc ballistics engine
#
# Three modes (tried in order):
#   1. Source build:    bclibc/ submodule present → add_subdirectory
#                       (pub.dev archive always includes submodule content)
#   2. Pre-installed:   bclibc_ffi already on disk → find_library
#                       (Flatpak: bclibc built as a separate module in /app/lib)
#   3. FetchContent:    neither above → download bclibc from GitHub at configure time
#                       (git dep via `dart pub get`, or submodule not yet initialised)
# ============================================================================

# Via symlink path: linux/flutter/ephemeral/.plugin_symlinks/dart_bclibc/linux/
# One level up crosses the .plugin_symlinks/dart_bclibc symlink transparently
# (OS resolves it at filesystem-access time) and lands on the package root,
# regardless of whether this is a local path dependency or a pub-cache package.
get_filename_component(PACKAGE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)
set(BCLIBC_ROOT "${PACKAGE_ROOT}/bclibc")

message(STATUS "dart_bclibc: package root  = ${PACKAGE_ROOT}")
message(STATUS "dart_bclibc: bclibc source = ${BCLIBC_ROOT}")

# Helper macro — shared by all three modes after the target is available.
macro(dart_bclibc_set_bundled_lib TARGET_OR_FILE)
  set(dart_bclibc_bundled_libraries "${TARGET_OR_FILE}" PARENT_SCOPE)
endmacro()

if(EXISTS "${BCLIBC_ROOT}/CMakeLists.txt")
  # ── Mode 1: submodule / pub.dev archive ────────────────────────────────────
  message(STATUS "dart_bclibc: Mode 1 — building from source at ${BCLIBC_ROOT}")
  add_subdirectory("${BCLIBC_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/bclibc_build")

else()
  # ── Mode 2: pre-installed library (Flatpak / system) ───────────────────────
  find_library(BCLIBC_FFI_LIB bclibc_ffi
    HINTS /app/lib /app/lib64 "${CMAKE_INSTALL_PREFIX}/lib" "${CMAKE_INSTALL_PREFIX}/lib64"
    NO_DEFAULT_PATH)

  if(BCLIBC_FFI_LIB)
    message(STATUS "dart_bclibc: Mode 2 — pre-installed library: ${BCLIBC_FFI_LIB}")
    # Resolve symlinks so Flutter bundles a plain .so, not a relative symlink.
    get_filename_component(BCLIBC_FFI_REAL "${BCLIBC_FFI_LIB}" REALPATH)
    set(BCLIBC_FFI_COPY "${CMAKE_CURRENT_BINARY_DIR}/libbclibc_ffi.so")
    configure_file("${BCLIBC_FFI_REAL}" "${BCLIBC_FFI_COPY}" COPYONLY)
    dart_bclibc_set_bundled_lib("${BCLIBC_FFI_COPY}")

  else()
    # ── Mode 3: FetchContent (git dep — submodule not initialised) ──────────
    # Use FetchContent_Populate + add_subdirectory directly, same as Mode 1.
    # FetchContent_MakeAvailable is intentionally avoided: in CMake 4.x it runs a
    # subbuild cmake that sets CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT=FALSE,
    # preventing the parent from overriding /usr/local with its bundle directory.
    message(STATUS "dart_bclibc: Mode 3 — fetching bclibc ${BCLIBC_VERSION} from GitHub")
    include(FetchContent)
    FetchContent_Declare(bclibc
      GIT_REPOSITORY https://github.com/ballistics-lab/bclibc.git
      GIT_TAG        ${BCLIBC_VERSION}
      GIT_SHALLOW    TRUE
    )
    FetchContent_GetProperties(bclibc)
    if(NOT bclibc_POPULATED)
      FetchContent_Populate(bclibc)
      add_subdirectory(${bclibc_SOURCE_DIR} ${bclibc_BINARY_DIR})
    endif()
  endif()
endif()

# install(TARGETS ... LIBRARY) installs the real versioned file together with
# its soname and namelink symlinks — all to the same DESTINATION, so the
# symlink chain stays valid inside the Flutter bundle.
# DESTINATION is intentionally relative: install() runs while the plugin is
# add_subdirectory'd, before the consumer sets INSTALL_BUNDLE_LIB_DIR. The
# relative path is resolved against CMAKE_INSTALL_PREFIX at install time.
if(TARGET bclibc_ffi)
  install(TARGETS bclibc_ffi
    LIBRARY DESTINATION lib
    COMPONENT Runtime)
endif()
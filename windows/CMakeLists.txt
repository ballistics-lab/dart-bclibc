# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "dart_bclibc")
project(${PROJECT_NAME} LANGUAGES C CXX)

set(BCLIBC_VERSION "a1e10fc5ead05fc59de65f5999d5f3304e62cf94")

# ============================================================================
# dart_bclibc – thin C wrapper over the embedded bclibc ballistics engine
# ============================================================================

# Find the root of the package
# Current path: windows/flutter/ephemeral/.plugin_symlinks/bclibc_ffi/windows/
# One level up crosses the .plugin_symlinks/bclibc_ffi symlink transparently
# and lands on the package root.
get_filename_component(PACKAGE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)
set(BCLIBC_ROOT "${PACKAGE_ROOT}/bclibc")

# Diagnostics (can be disabled after debugging)
message(STATUS "Package root: ${PACKAGE_ROOT}")
message(STATUS "bclibc path: ${BCLIBC_ROOT}")

# ── Mode 1: submodule / pub.dev archive ──────────────────────────────────────
# ── Mode 2: FetchContent (git dep — submodule not initialised) ────────────────
if(EXISTS "${BCLIBC_ROOT}/CMakeLists.txt")
  message(STATUS "dart_bclibc: Mode 1 — building from source at ${BCLIBC_ROOT}")
  add_subdirectory("${BCLIBC_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/bclibc_build")
else()
  message(STATUS "dart_bclibc: Mode 2 — fetching bclibc ${BCLIBC_VERSION} from GitHub")
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

# Declare the DLL as a bundled library — Flutter's generated_plugins.cmake
# collects dart_bclibc_bundled_libraries into PLUGIN_BUNDLED_LIBRARIES and the
# app's CMakeLists installs it to the bundle root via the standard loop.
# flutter_assemble is wired before the main binary, so hooking bclibc_ffi onto
# it ensures Visual Studio builds bclibc_ffi whenever it builds the app.
if(TARGET bclibc_ffi)
  set(dart_bclibc_bundled_libraries $<TARGET_FILE:bclibc_ffi> PARENT_SCOPE)
  if(TARGET flutter_assemble)
    add_dependencies(flutter_assemble bclibc_ffi)
  endif()
endif()
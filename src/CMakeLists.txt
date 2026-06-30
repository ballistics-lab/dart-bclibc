cmake_minimum_required(VERSION 3.13)

set(PROJECT_NAME "dart_bclibc")
project(${PROJECT_NAME} LANGUAGES C CXX)

# src/ is a direct child of the package root — one level up lands on it.
# Android Gradle resolves this path directly (no symlink traversal needed).
get_filename_component(PACKAGE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)
set(BCLIBC_ROOT "${PACKAGE_ROOT}/bclibc")

message(STATUS "[bclibc_ffi/android] Package root: ${PACKAGE_ROOT}")
message(STATUS "[bclibc_ffi/android] bclibc path:  ${BCLIBC_ROOT}")

# ── Mode 1: submodule / pub.dev archive ──────────────────────────────────────
# ── Mode 2: FetchContent (git dep — submodule not initialised) ────────────────
if(EXISTS "${BCLIBC_ROOT}/CMakeLists.txt")
  message(STATUS "dart_bclibc: Mode 1 — building from source at ${BCLIBC_ROOT}")
  add_subdirectory("${BCLIBC_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/bclibc_build")
else()
  message(STATUS "dart_bclibc: Mode 2 — fetching bclibc v1.1.4 from GitHub")
  include(FetchContent)
  FetchContent_Declare(bclibc
    GIT_REPOSITORY https://github.com/ballistics-lab/bclibc.git
    GIT_TAG        v1.1.4
    GIT_SHALLOW    TRUE
  )
  FetchContent_MakeAvailable(bclibc)
endif()

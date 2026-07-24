cmake_minimum_required(VERSION 3.13)

set(PROJECT_NAME "dart_bclibc")
project(${PROJECT_NAME} LANGUAGES C CXX)

set(BCLIBC_VERSION "704759435a123aac1253b64e0f08f68ee2d18f81")

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

# Android shared libs don't use versioned symlinks, so TARGET_FILE is fine.
# The Gradle build system collects bclibc_ffi via add_subdirectory directly.

cmake_minimum_required(VERSION 3.13)

set(PROJECT_NAME "dart_bclibc")
project(${PROJECT_NAME} LANGUAGES C CXX)

# src/ is a direct child of the package root — one level up lands on it.
# Android Gradle resolves this path directly (no symlink traversal needed).
get_filename_component(PACKAGE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)
set(BCLIBC_ROOT "${PACKAGE_ROOT}/bclibc")

message(STATUS "[bclibc_ffi/android] Package root: ${PACKAGE_ROOT}")
message(STATUS "[bclibc_ffi/android] bclibc path:  ${BCLIBC_ROOT}")

if(NOT EXISTS "${BCLIBC_ROOT}")
    message(FATAL_ERROR "bclibc not found at ${BCLIBC_ROOT}")
endif()

if(NOT EXISTS "${BCLIBC_ROOT}/CMakeLists.txt")
    message(FATAL_ERROR "bclibc CMakeLists.txt not found at ${BCLIBC_ROOT}")
endif()

add_subdirectory(
    "${BCLIBC_ROOT}"
    "${CMAKE_CURRENT_BINARY_DIR}/bclibc_ffi_build"
)

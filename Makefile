.PHONY: build ffigen test clean

# Cross-platform helpers
ifeq ($(OS),Windows_NT)
  NPROC  := $(NUMBER_OF_PROCESSORS)
  RM_DIR := cmake -E remove_directory
else
  NPROC  := $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
  RM_DIR := rm -rf
endif

BUILD_TYPE ?= Debug

# Build the native shared library via CMake (used by ffigen and dart tests).
# For flutter apps, the library is built automatically by flutter build.
build:
	git submodule update --init
	cmake -S bclibc -B build/bclibc -DCMAKE_BUILD_TYPE=$(BUILD_TYPE)
	cmake --build build/bclibc --parallel $(NPROC)

# Re-generate Dart FFI bindings from the C header.
# Requires LLVM/Clang:
#   Linux:   sudo apt install libclang-dev clang
#   macOS:   brew install llvm
#   Windows: winget install LLVM
ffigen: build
	dart run ffigen --config ffigen.yaml

# Run Dart tests (native library must be built first).
test: build
	dart test

clean:
	$(RM_DIR) build/bclibc
	$(RM_DIR) lib/ffi/bclibc_bindings.g.dart

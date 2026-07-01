.PHONY: build ffigen test clean sync-bclibc

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
# Consuming packages should use `dart run dart_bclibc:build_native` instead
# (see bin/build_native.dart) — this target additionally initializes the
# bclibc submodule, which only applies to a local clone of this repo.
build:
	git submodule update --init
	dart run bin/build_native.dart $(BUILD_TYPE)

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

format:
	dart format bin/ lib/

clean:
	$(RM_DIR) build/bclibc
	$(RM_DIR) lib/ffi/bclibc_bindings.g.dart

# Sync BCLIBC_VERSION in all platform CMakeLists.txt to the commit the submodule
# is currently pinned to.  Run after bumping the bclibc submodule.
sync-bclibc:
	$(eval REF := $(shell git submodule status bclibc | awk '{print $$1}' | tr -d '+-'))
	@echo "Syncing BCLIBC_VERSION → $(REF)"
	@sed -i 's/set(BCLIBC_VERSION "[^"]*")/set(BCLIBC_VERSION "$(REF)")/' \
		linux/CMakeLists.txt windows/CMakeLists.txt src/CMakeLists.txt

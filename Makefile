.PHONY: build ffigen test clean format sync-bclibc verify-bclibc

# Cross-platform helpers
ifeq ($(OS),Windows_NT)
  RM_DIR := cmake -E remove_directory
else
  RM_DIR := rm -rf
endif

BUILD_TYPE ?= Release

# Build the native shared library via CMake (used by ffigen and dart tests)
# and copy it into dart/lib/native/ — see dart/bin/build_native.dart.
# For Flutter apps, the library is built automatically by `flutter build`
# (via dart_bclibc_flutter's platform CMake integration instead).
# This target additionally initializes both bclibc submodules, which only
# applies to a local clone of this repo.
build:
	git submodule update --init dart/bclibc flutter/bclibc
	cd dart && dart pub get && dart run bin/build_native.dart $(BUILD_TYPE)

# Re-generate Dart FFI bindings from the C header.
# Requires LLVM/Clang:
#   Linux:   sudo apt install libclang-dev clang
#   macOS:   brew install llvm
#   Windows: winget install LLVM
ffigen: build
	cd dart && dart run ffigen --config ffigen.yaml

# Run dart/'s test suite (native library must be built first).
test: build
	cd dart && dart test

format:
	cd dart && dart format bin/ lib/
	cd flutter && dart format lib/

clean:
	$(RM_DIR) dart/build
	$(RM_DIR) dart/lib/native
	$(RM_DIR) dart/lib/ffi/bclibc_bindings.g.dart

# Sync BCLIBC_VERSION in flutter/'s platform CMakeLists.txt to the commit
# dart/bclibc is currently pinned to, then re-pin flutter/bclibc to match.
# Run after bumping the dart/bclibc submodule.
sync-bclibc:
	$(eval REF := $(shell git submodule status dart/bclibc | awk '{print $$1}' | tr -d '+-'))
	@echo "Syncing BCLIBC_VERSION → $(REF)"
	@sed -i 's/set(BCLIBC_VERSION "[^"]*")/set(BCLIBC_VERSION "$(REF)")/' \
		flutter/linux/CMakeLists.txt flutter/windows/CMakeLists.txt flutter/src/CMakeLists.txt
	cd flutter/bclibc && git fetch --quiet && git checkout --quiet $(REF)
	git add flutter/bclibc

# dart/bclibc and flutter/bclibc are two separate submodule checkouts of the
# same upstream repo — each published package (dart_bclibc,
# dart_bclibc_flutter) has to be self-contained, so there's no reliable way
# to share one checkout between them (same reasoning as
# ob-dump/scripts/ci/verify-lmdb-vendor.sh for its plain-vendored, non-
# submodule native dependency). This just confirms they haven't drifted
# apart instead of trying to eliminate the duplication.
verify-bclibc:
	@dart_ref=$$(git submodule status dart/bclibc | awk '{print $$1}' | tr -d '+-'); \
	flutter_ref=$$(git submodule status flutter/bclibc | awk '{print $$1}' | tr -d '+-'); \
	if [ "$$dart_ref" != "$$flutter_ref" ]; then \
		echo "error: dart/bclibc ($$dart_ref) and flutter/bclibc ($$flutter_ref) point at different commits"; \
		exit 1; \
	fi; \
	echo "OK: dart/bclibc and flutter/bclibc both at $$dart_ref"

.PHONY: submodule ffigen test web-test format build-wasm verify-bclibc install-hooks

# The native library needs no build step here: hook/build.dart compiles
# the bundled bclibc/ sources whenever `dart run`/`dart test`/`flutter
# build` needs it. Only a local clone has to initialize the submodule first.
submodule:
	git submodule update --init bclibc

# Re-generate the @Native FFI bindings (lib/ffi/bclibc_bindings.g.dart)
# from the C header. Requires LLVM/Clang:
#   Linux:   sudo apt install libclang-dev clang
#   macOS:   brew install llvm
#   Windows: winget install LLVM
ffigen: submodule
	dart pub get && dart run ffigen --config ffigen.yaml

# Native (dart:ffi) tests; the build hook compiles the library on the way.
test: submodule
	dart pub get && dart test test/ffi_test.dart test/hit_result_test.dart test/unit_test.dart test/async_calculator_test.dart

# Web tests (dart:js_interop against the wasm module embedded in the package).
web-test:
	dart pub get && dart test -p chrome test/web/

format:
	dart format hook/ lib/ test/

# Rebuild the wasm module embedded in the package (lib/ffi/bclibc_wasm.g.dart)
# from the pinned bclibc submodule: one bare wasm (no Emscripten, no JS glue,
# no C++ exceptions -- bclibc never throws) built with zig, which comes from the
# `ziglang` package:
#   uv run --with ziglang make build-wasm        (or zig on PATH, or ZIG=/path/to/zig)
# wasi-sdk builds the same module, ~12x bigger:
#   make build-wasm WASM_TOOLCHAIN=wasi-sdk WASI_SDK_PATH=/path/to/wasi-sdk-34.0
# Run `make verify-bclibc` afterward (this target does) to ensure the embedded
# version matches the submodule.
WASM_TOOLCHAIN ?= zig
ZIG ?=
WASI_SDK_PATH ?=

build-wasm: submodule
ifeq ($(WASM_TOOLCHAIN),zig)
	$(MAKE) -C bclibc wasm-zig $(if $(ZIG),ZIG=$(ZIG))
	python3 scripts/embed_wasm.py bclibc/build/wasm-zig/bclibc_wasm.wasm
else
	@test -n "$(WASI_SDK_PATH)" || { echo "set WASI_SDK_PATH=/path/to/wasi-sdk (https://github.com/WebAssembly/wasi-sdk/releases)"; exit 1; }
	$(MAKE) -C bclibc wasm WASI_SDK_PATH=$(WASI_SDK_PATH)
	python3 scripts/embed_wasm.py bclibc/build/wasm/bclibc_wasm.wasm
endif
	git add lib/ffi/bclibc_wasm.g.dart
	$(MAKE) verify-bclibc

# Confirms the single bclibc pin -- the bclibc submodule, the embedded
# wasm module and the CHANGELOG -- hasn't drifted. See scripts/ci/verify-bclibc.sh.
verify-bclibc:
	scripts/ci/verify-bclibc.sh

# Run verify-bclibc as a git pre-commit hook for this clone.
install-hooks:
	git config core.hooksPath scripts/hooks
	@echo "Installed: pre-commit → scripts/ci/verify-bclibc.sh"

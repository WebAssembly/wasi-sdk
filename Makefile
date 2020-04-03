# Any copyright is dedicated to the Public Domain.
# http://creativecommons.org/publicdomain/zero/1.0/

ROOT_DIR=${CURDIR}
LLVM_PROJ_DIR?=$(ROOT_DIR)/src/llvm-project
PREFIX?=/opt/wasi-sdk

CLANG_VERSION=$(shell ./llvm_version.sh $(LLVM_PROJ_DIR))
VERSION:=$(shell ./version.sh)
DEBUG_PREFIX_MAP=-fdebug-prefix-map=$(ROOT_DIR)=wasisdk://v$(VERSION)

default: build
	@echo "Use -fdebug-prefix-map=$(ROOT_DIR)=wasisdk://v$(VERSION)"

check:
	cd tests && PATH="$(PREFIX)/bin:$$PATH" ./run.sh

clean:
	rm -rf build $(PREFIX)

build/llvm.BUILT:
	mkdir -p build/llvm
	cmake -B build/llvm -G Ninja \
		-DCMAKE_BUILD_TYPE=MinSizeRel \
		-DCMAKE_INSTALL_PREFIX=$(PREFIX) \
		-DLLVM_TARGETS_TO_BUILD=WebAssembly \
		-DLLVM_DEFAULT_TARGET_TRIPLE=wasm32-wasi \
		-DLLVM_ENABLE_PROJECTS="lld;clang;clang-tools-extra" \
		-DDEFAULT_SYSROOT=$(PREFIX)/share/wasi-sysroot \
		-DLLVM_INSTALL_BINUTILS_SYMLINKS=TRUE \
		$(LLVM_PROJ_DIR)/llvm
	ninja $(NINJA_FLAGS) -v -C build/llvm \
		install-clang \
		install-clang-format \
		install-clang-tidy \
		install-clang-apply-replacements \
		install-lld \
		install-llvm-ranlib \
		install-llvm-strip \
		install-llvm-dwarfdump \
		$(if $(patsubst 8.%,,$(CLANG_VERSION)),install-clang-resource-headers,install-clang-headers) \
		install-ar \
		install-ranlib \
		install-strip \
		install-nm \
		install-size \
		install-strings \
		install-objdump \
		install-objcopy \
		install-c++filt \
		llvm-config
	touch build/llvm.BUILT

build/wasi-libc.BUILT: build/llvm.BUILT
	$(MAKE) -C $(ROOT_DIR)/src/wasi-libc \
		WASM_CC=$(PREFIX)/bin/clang \
		SYSROOT=$(PREFIX)/share/wasi-sysroot \
		CLANG_VERSION=$(CLANG_VERSION)
	touch build/wasi-libc.BUILT

build/compiler-rt.BUILT: build/llvm.BUILT
	# Do the conventional build, and install it.
	mkdir -p build/compiler-rt
	cmake -B build/compiler-rt -G Ninja \
		-DCMAKE_BUILD_TYPE=RelWithDebInfo \
		-DCMAKE_TOOLCHAIN_FILE=$(ROOT_DIR)/wasi-sdk.cmake \
		-DCOMPILER_RT_BAREMETAL_BUILD=On \
		-DCOMPILER_RT_BUILD_XRAY=OFF \
		-DCOMPILER_RT_INCLUDE_TESTS=OFF \
		-DCOMPILER_RT_HAS_FPIC_FLAG=OFF \
		-DCOMPILER_RT_ENABLE_IOS=OFF \
		-DCOMPILER_RT_DEFAULT_TARGET_ONLY=On \
		-DWASI_SDK_PREFIX=$(PREFIX) \
		-DCMAKE_C_FLAGS="$(DEBUG_PREFIX_MAP)" \
		-DLLVM_CONFIG_PATH=$(ROOT_DIR)/build/llvm/bin/llvm-config \
		-DCOMPILER_RT_OS_DIR=wasi \
		-DCMAKE_INSTALL_PREFIX=$(PREFIX)/lib/clang/$(CLANG_VERSION)/ \
		-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
		$(LLVM_PROJ_DIR)/compiler-rt/lib/builtins
	ninja $(NINJA_FLAGS) -v -C build/compiler-rt install
	# Install clang-provided headers.
	cp -R $(ROOT_DIR)/build/llvm/lib/clang $(PREFIX)/lib/
	touch build/compiler-rt.BUILT

# Flags common to both the non-LTO and LTO builds of libcxx.
LIBCXX_CMAKE_FLAGS = \
    -DCMAKE_TOOLCHAIN_FILE=$(ROOT_DIR)/wasi-sdk.cmake \
    -DLLVM_CONFIG_PATH=$(ROOT_DIR)/build/llvm/bin/llvm-config \
    -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
    -DLIBCXX_ENABLE_THREADS:BOOL=OFF \
    -DLIBCXX_HAS_PTHREAD_API:BOOL=OFF \
    -DLIBCXX_HAS_EXTERNAL_THREAD_API:BOOL=OFF \
    -DLIBCXX_BUILD_EXTERNAL_THREAD_LIBRARY:BOOL=OFF \
    -DLIBCXX_HAS_WIN32_THREAD_API:BOOL=OFF \
    -DCMAKE_BUILD_TYPE=RelWithDebugInfo \
    -DLIBCXX_ENABLE_SHARED:BOOL=OFF \
    -DLIBCXX_ENABLE_EXPERIMENTAL_LIBRARY:BOOL=OFF \
    -DLIBCXX_ENABLE_EXCEPTIONS:BOOL=OFF \
    -DLIBCXX_ENABLE_FILESYSTEM:BOOL=OFF \
    -DLIBCXX_CXX_ABI=libcxxabi \
    -DLIBCXX_CXX_ABI_INCLUDE_PATHS=$(LLVM_PROJ_DIR)/libcxxabi/include \
    -DLIBCXX_HAS_MUSL_LIBC:BOOL=ON \
    -DLIBCXX_ABI_VERSION=2 \
    -DWASI_SDK_PREFIX=$(PREFIX) \
    --debug-trycompile

build/libcxx.BUILT: build/llvm.BUILT build/compiler-rt.BUILT build/wasi-libc.BUILT
	# Do the conventional build.
	mkdir -p build/libcxx
	cmake -B build/libcxx -G Ninja $(LIBCXX_CMAKE_FLAGS) \
	    -DCMAKE_C_FLAGS="$(DEBUG_PREFIX_MAP)" \
	    -DCMAKE_CXX_FLAGS="$(DEBUG_PREFIX_MAP)" \
	    -DLIBCXX_LIBDIR_SUFFIX=/wasm32-wasi \
	    $(LLVM_PROJ_DIR)/libcxx
	ninja $(NINJA_FLAGS) -v -C build/libcxx
	# Now build the same thing but with LTO enabled.
	mkdir -p build/libcxx.llvm-lto
	cmake -B build/libcxx.llvm-lto -G Ninja $(LIBCXX_CMAKE_FLAGS) \
	    -DCMAKE_C_FLAGS="-flto $(DEBUG_PREFIX_MAP)" \
	    -DCMAKE_CXX_FLAGS="-flto $(DEBUG_PREFIX_MAP)" \
	    -DLIBCXX_LIBDIR_SUFFIX=/wasm32-wasi/llvm-lto/$(CLANG_VERSION) \
	    $(LLVM_PROJ_DIR)/libcxx
	ninja $(NINJA_FLAGS) -v -C build/libcxx.llvm-lto
	# Do the install.
	ninja $(NINJA_FLAGS) -v -C build/libcxx install
	ninja $(NINJA_FLAGS) -v -C build/libcxx.llvm-lto install
	touch build/libcxx.BUILT

# Flags common to both the non-LTO and LTO builds of libcxxabi.
LIBCXXABI_CMAKE_FLAGS = \
    -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
    -DCMAKE_CXX_COMPILER_WORKS=ON \
    -DCMAKE_C_COMPILER_WORKS=ON \
    -DLIBCXXABI_ENABLE_EXCEPTIONS:BOOL=OFF \
    -DLIBCXXABI_ENABLE_SHARED:BOOL=OFF \
    -DLIBCXXABI_SILENT_TERMINATE:BOOL=ON \
    -DLIBCXXABI_ENABLE_THREADS:BOOL=OFF \
    -DLIBCXXABI_HAS_PTHREAD_API:BOOL=OFF \
    -DLIBCXXABI_HAS_EXTERNAL_THREAD_API:BOOL=OFF \
    -DLIBCXXABI_BUILD_EXTERNAL_THREAD_LIBRARY:BOOL=OFF \
    -DLIBCXXABI_HAS_WIN32_THREAD_API:BOOL=OFF \
    $(if $(patsubst 8.%,,$(CLANG_VERSION)),-DLIBCXXABI_ENABLE_PIC:BOOL=OFF,) \
    -DCXX_SUPPORTS_CXX11=ON \
    -DLLVM_COMPILER_CHECKED=ON \
    -DCMAKE_BUILD_TYPE=RelWithDebugInfo \
    -DLIBCXXABI_LIBCXX_PATH=$(LLVM_PROJ_DIR)/libcxx \
    -DLIBCXXABI_LIBCXX_INCLUDES=$(PREFIX)/share/wasi-sysroot/include/c++/v1 \
    -DLLVM_CONFIG_PATH=$(ROOT_DIR)/build/llvm/bin/llvm-config \
    -DCMAKE_TOOLCHAIN_FILE=$(ROOT_DIR)/wasi-sdk.cmake \
    -DWASI_SDK_PREFIX=$(PREFIX) \
    -DUNIX:BOOL=ON \
    --debug-trycompile

build/libcxxabi.BUILT: build/libcxx.BUILT build/llvm.BUILT
	# Do the conventional build.
	mkdir -p build/libcxxabi
	cmake -B build/libcxxabi -G Ninja $(LIBCXXABI_CMAKE_FLAGS) \
	    -DCMAKE_C_FLAGS="$(DEBUG_PREFIX_MAP)" \
	    -DCMAKE_CXX_FLAGS="$(DEBUG_PREFIX_MAP)" \
	    -DLIBCXXABI_LIBDIR_SUFFIX=/wasm32-wasi \
	    $(LLVM_PROJ_DIR)/libcxxabi
	ninja $(NINJA_FLAGS) -v -C build/libcxxabi
	# Now build the same thing but with LTO enabled.
	mkdir -p build/libcxxabi.llvm-lto
	cmake -B build/libcxxabi.llvm-lto -G Ninja $(LIBCXXABI_CMAKE_FLAGS) \
	    -DCMAKE_C_FLAGS="-flto $(DEBUG_PREFIX_MAP)" \
	    -DCMAKE_CXX_FLAGS="-flto $(DEBUG_PREFIX_MAP)" \
	    -DLIBCXXABI_LIBDIR_SUFFIX=/wasm32-wasi/llvm-lto/$(CLANG_VERSION) \
	    $(LLVM_PROJ_DIR)/libcxxabi
	ninja $(NINJA_FLAGS) -v -C build/libcxxabi.llvm-lto
	# Do the install.
	ninja $(NINJA_FLAGS) -v -C build/libcxxabi install
	ninja $(NINJA_FLAGS) -v -C build/libcxxabi.llvm-lto install
	touch build/libcxxabi.BUILT

build/config.BUILT:
	mkdir -p $(PREFIX)/share/misc
	cp src/config/config.sub src/config/config.guess $(PREFIX)/share/misc
	mkdir -p $(PREFIX)/share/cmake
	cp wasi-sdk.cmake $(PREFIX)/share/cmake
	touch build/config.BUILT

build: build/llvm.BUILT build/wasi-libc.BUILT build/compiler-rt.BUILT build/libcxxabi.BUILT build/libcxx.BUILT build/config.BUILT

strip: build/llvm.BUILT
	./strip_symbols.sh $(PREFIX)

package: build/package.BUILT

build/package.BUILT: build strip
	mkdir -p dist
	command -v dpkg-deb >/dev/null && ./deb_from_installation.sh $(shell pwd)/dist || true
	./tar_from_installation.sh $(shell pwd)/dist
	touch build/package.BUILT

.PHONY: default clean build strip package check

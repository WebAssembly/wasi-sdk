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

clean:
	rm -rf build $(PREFIX)

build/llvm.BUILT:
	mkdir -p build/llvm
	cd build/llvm; cmake -G "Unix Makefiles" \
		-DCMAKE_BUILD_TYPE=MinSizeRel \
		-DCMAKE_INSTALL_PREFIX=$(PREFIX) \
		-DLLVM_TARGETS_TO_BUILD=WebAssembly \
		-DLLVM_DEFAULT_TARGET_TRIPLE=wasm32-wasi \
		-DLLVM_EXTERNAL_CLANG_SOURCE_DIR=$(LLVM_PROJ_DIR)/clang \
		-DLLVM_EXTERNAL_LLD_SOURCE_DIR=$(LLVM_PROJ_DIR)/lld \
		-DLLVM_ENABLE_PROJECTS="lld;clang" \
		-DDEFAULT_SYSROOT=$(PREFIX)/share/sysroot \
		$(LLVM_PROJ_DIR)/llvm
	cd build/llvm; $(MAKE) -j 8 \
		install-clang \
		install-lld \
		install-llc \
		install-llvm-ar \
		install-llvm-ranlib \
		install-llvm-dwarfdump \
		$(if $(patsubst 8.%,,$(CLANG_VERSION)),install-clang-resource-headers,install-clang-headers) \
		install-llvm-nm \
		install-llvm-size \
		llvm-config
	touch build/llvm.BUILT

build/wasi-sysroot.BUILT: build/llvm.BUILT
	make -C $(ROOT_DIR)/src/wasi-sysroot \
		WASM_CC=$(PREFIX)/bin/clang \
		SYSROOT=$(PREFIX)/share/sysroot
	touch build/wasi-sysroot.BUILT

build/compiler-rt.BUILT: build/llvm.BUILT
	mkdir -p build/compiler-rt
	cd build/compiler-rt; cmake -G "Unix Makefiles" \
		-DCMAKE_BUILD_TYPE=RelWithDebInfo \
		-DCMAKE_TOOLCHAIN_FILE=$(ROOT_DIR)/wasi-sdk.cmake \
		-DCOMPILER_RT_BAREMETAL_BUILD=On \
		-DCOMPILER_RT_BUILD_XRAY=OFF \
		-DCOMPILER_RT_INCLUDE_TESTS=OFF \
		-DCOMPILER_RT_HAS_FPIC_FLAG=OFF \
		-DCOMPILER_RT_ENABLE_IOS=OFF \
		-DCOMPILER_RT_DEFAULT_TARGET_ONLY=On \
		-DWASI_SDK_PREFIX=$(PREFIX) \
		-DCMAKE_C_FLAGS="-O1 $(DEBUG_PREFIX_MAP)" \
		-DLLVM_CONFIG_PATH=$(ROOT_DIR)/build/llvm/bin/llvm-config \
		-DCOMPILER_RT_OS_DIR=wasi \
		-DCMAKE_INSTALL_PREFIX=$(PREFIX)/lib/clang/$(CLANG_VERSION)/ \
		-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
		$(LLVM_PROJ_DIR)/compiler-rt/lib/builtins
	cd build/compiler-rt; make -j 8 install
	cp -R $(ROOT_DIR)/build/llvm/lib/clang $(PREFIX)/lib/
	touch build/compiler-rt.BUILT

build/libcxx.BUILT: build/llvm.BUILT build/compiler-rt.BUILT build/wasi-sysroot.BUILT
	mkdir -p build/libcxx
	cd build/libcxx; cmake -G "Unix Makefiles" \
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
		-DCMAKE_C_FLAGS="$(DEBUG_PREFIX_MAP)" \
		-DCMAKE_CXX_FLAGS="$(DEBUG_PREFIX_MAP)" \
		--debug-trycompile \
		$(LLVM_PROJ_DIR)/libcxx
	cd build/libcxx; make -j 8 install
	# libc++abi.a doesn't do a multiarch install, so fix it up.
	mv $(PREFIX)/share/sysroot/lib/libc++.a $(PREFIX)/share/sysroot/lib/wasm32-wasi/
	touch build/libcxx.BUILT

build/libcxxabi.BUILT: build/libcxx.BUILT build/llvm.BUILT
	mkdir -p build/libcxxabi
	cd build/libcxxabi; cmake -G "Unix Makefiles" \
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
		-DLIBCXXABI_LIBCXX_INCLUDES=$(PREFIX)/share/sysroot/include/c++/v1 \
		-DLLVM_CONFIG_PATH=$(ROOT_DIR)/build/llvm/bin/llvm-config \
		-DCMAKE_TOOLCHAIN_FILE=$(ROOT_DIR)/wasi-sdk.cmake \
		-DWASI_SDK_PREFIX=$(PREFIX) \
		-DCMAKE_C_FLAGS="$(DEBUG_PREFIX_MAP) -I$(PREFIX)/share/sysroot/include" \
		-DCMAKE_CXX_FLAGS="$(DEBUG_PREFIX_MAP) -I$(PREFIX)/share/sysroot/include/c++/v1" \
		-DUNIX:BOOL=ON \
		--debug-trycompile \
		$(LLVM_PROJ_DIR)/libcxxabi
	cd build/libcxxabi; make -j 8 install
	# libc++abi.a doesn't do a multiarch install, so fix it up.
	mv $(PREFIX)/share/sysroot/lib/libc++abi.a $(PREFIX)/share/sysroot/lib/wasm32-wasi/
	touch build/libcxxabi.BUILT

build/config.BUILT:
	mkdir -p $(PREFIX)/share/misc
	cp src/config/config.sub src/config/config.guess $(PREFIX)/share/misc
	touch build/config.BUILT

build: build/llvm.BUILT build/wasi-sysroot.BUILT build/compiler-rt.BUILT build/libcxxabi.BUILT build/libcxx.BUILT build/config.BUILT

strip: build/llvm.BUILT
	cd $(PREFIX)/bin; strip clang-8 llc lld llvm-ar

package: build/package.BUILT

build/package.BUILT: build strip
	command -v dpkg-deb >/dev/null && ./deb_from_installation.sh || true
	./tar_from_installation.sh
	touch build/package.BUILT

.PHONY: default clean build strip package

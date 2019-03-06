# Any copyright is dedicated to the Public Domain.
# http://creativecommons.org/publicdomain/zero/1.0/

ROOT_DIR=${CURDIR}
PREFIX?=/opt/wasi-sdk
CLANG_VERSION=8.0.0

VERSION=0.2
DEBUG_PREFIX_MAP=-fdebug-prefix-map=$(ROOT_DIR)=wasmception://v$(VERSION)

default: build
	echo "Use -fdebug-prefix-map=$(ROOT_DIR)=wasmception://v$(VERSION)"

clean:
	rm -rf build $(PREFIX)

build/llvm.BUILT:
	mkdir -p build/llvm
	cd build/llvm; cmake -G "Unix Makefiles" \
		-DCMAKE_BUILD_TYPE=MinSizeRel \
		-DCMAKE_INSTALL_PREFIX=$(PREFIX) \
		-DLLVM_TARGETS_TO_BUILD=WebAssembly \
		-DLLVM_DEFAULT_TARGET_TRIPLE=wasm32-unknown-wasi \
		-DLLVM_EXTERNAL_CLANG_SOURCE_DIR=$(ROOT_DIR)/src/llvm-project/clang \
		-DLLVM_EXTERNAL_LLD_SOURCE_DIR=$(ROOT_DIR)/src/llvm-project/lld \
		-DLLVM_ENABLE_PROJECTS="lld;clang" \
		-DDEFAULT_SYSROOT=$(PREFIX)/share/sysroot \
		$(ROOT_DIR)/src/llvm-project/llvm
	cd build/llvm; $(MAKE) -j 8 \
		install-clang \
		install-lld \
		install-llc \
		install-llvm-ar \
		install-llvm-ranlib \
		install-llvm-dwarfdump \
		install-clang-headers \
		install-llvm-nm \
		install-llvm-size \
		llvm-config
	touch build/llvm.BUILT

build/reference-sysroot.BUILT: build/llvm.BUILT
	make -C $(ROOT_DIR)/src/reference-sysroot \
		WASM_CC=$(PREFIX)/bin/clang \
		SYSROOT=$(PREFIX)/share/sysroot
	touch build/reference-sysroot.BUILT

build/compiler-rt.BUILT: build/llvm.BUILT
	mkdir -p build/compiler-rt
	cd build/compiler-rt; cmake -G "Unix Makefiles" \
		-DCMAKE_BUILD_TYPE=RelWithDebInfo \
		-DCMAKE_TOOLCHAIN_FILE=$(ROOT_DIR)/wasmi-sdk.cmake \
		-DCOMPILER_RT_BAREMETAL_BUILD=On \
		-DCOMPILER_RT_BUILD_XRAY=OFF \
		-DCOMPILER_RT_INCLUDE_TESTS=OFF \
		-DCOMPILER_RT_ENABLE_IOS=OFF \
		-DCOMPILER_RT_DEFAULT_TARGET_ONLY=On \
		-DWASM_SDK_PREFIX=$(PREFIX) \
		-DCMAKE_C_FLAGS="-O1 $(DEBUG_PREFIX_MAP)" \
		-DLLVM_CONFIG_PATH=$(ROOT_DIR)/build/llvm/bin/llvm-config \
		-DCOMPILER_RT_OS_DIR=wasi \
		-DCMAKE_INSTALL_PREFIX=$(PREFIX)/lib/clang/$(CLANG_VERSION)/ \
		-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
		$(ROOT_DIR)/src/llvm-project/compiler-rt/lib/builtins
	cd build/compiler-rt; make -j 8 install
	cp -R $(ROOT_DIR)/build/llvm/lib/clang $(PREFIX)/lib/
	touch build/compiler-rt.BUILT

build/libcxx.BUILT: build/llvm.BUILT build/compiler-rt.BUILT build/reference-sysroot.BUILT
	mkdir -p build/libcxx
	cd build/libcxx; cmake -G "Unix Makefiles" \
		-DCMAKE_TOOLCHAIN_FILE=$(ROOT_DIR)/wasi-sdk.cmake \
		-DLLVM_CONFIG_PATH=$(ROOT_DIR)/build/llvm/bin/llvm-config \
		-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
		-DLIBCXX_HAS_PTHREAD_API:BOOL=ON \
		-DCMAKE_BUILD_TYPE=RelWithDebugInfo \
		-DLIBCXX_ENABLE_SHARED:BOOL=OFF \
		-DLIBCXX_ENABLE_EXPERIMENTAL_LIBRARY:BOOL=OFF \
		-DLIBCXX_ENABLE_EXCEPTIONS:BOOL=OFF \
		-DLIBCXX_CXX_ABI=libcxxabi \
		-DLIBCXX_CXX_ABI_INCLUDE_PATHS=$(ROOT_DIR)/src/llvm-project/libcxxabi/include \
		-DLIBCXX_HAS_MUSL_LIBC:BOOL=ON \
		-DLIBCXX_ABI_VERSION=2 \
		-DWASM_SDK_PREFIX=$(PREFIX) \
		-DCMAKE_C_FLAGS="$(DEBUG_PREFIX_MAP)" \
		-DCMAKE_CXX_FLAGS="$(DEBUG_PREFIX_MAP)" \
		--debug-trycompile \
		$(ROOT_DIR)/src/llvm-project/libcxx
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
		-DLIBCXXABI_HAS_PTHREAD_API:BOOL=ON \
		-DCXX_SUPPORTS_CXX11=ON \
		-DLLVM_COMPILER_CHECKED=ON \
		-DCMAKE_BUILD_TYPE=RelWithDebugInfo \
		-DLIBCXXABI_LIBCXX_PATH=$(ROOT_DIR)/src/llvm-project/libcxx \
		-DLIBCXXABI_LIBCXX_INCLUDES=$(PREFIX)/share/sysroot/include/c++/v1 \
		-DLLVM_CONFIG_PATH=$(ROOT_DIR)/build/llvm/bin/llvm-config \
		-DCMAKE_TOOLCHAIN_FILE=$(ROOT_DIR)/wasi-sdk.cmake \
		-DWASM_SDK_PREFIX=$(PREFIX) \
		-DCMAKE_C_FLAGS="$(DEBUG_PREFIX_MAP)" \
		-DCMAKE_CXX_FLAGS="$(DEBUG_PREFIX_MAP)" \
		-DUNIX:BOOL=ON \
		--debug-trycompile \
		$(ROOT_DIR)/src/llvm-project/libcxxabi
	cd build/libcxxabi; make -j 8 install
	# libc++abi.a doesn't do a multiarch install, so fix it up.
	mv $(PREFIX)/share/sysroot/lib/libc++abi.a $(PREFIX)/share/sysroot/lib/wasm32-wasi/
	touch build/libcxxabi.BUILT

build: build/llvm.BUILT build/reference-sysroot.BUILT build/compiler-rt.BUILT build/libcxxabi.BUILT build/libcxx.BUILT

strip: build/llvm.BUILT
	cd $(PREFIX)/bin; strip clang-8 llc lld llvm-ar

package: build/package.BUILT

build/package.BUILT: build
	./package.sh
	touch build/package.BUILT

.PHONY: default clean build strip package

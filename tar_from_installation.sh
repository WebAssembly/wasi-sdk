#!/usr/bin/env bash
set -ex
if [ -n "$1" ]; then
    VERSION="$1"
else
    VERSION=`./version.sh`
fi

PKGDIR=build/wasi-sdk-$VERSION

case "$(uname -s)" in
    Linux*)     MACHINE=linux;;
    Darwin*)    MACHINE=macos;;
    CYGWIN*)    MACHINE=cygwin;;
    MINGW*)     MACHINE=mingw;;
    *)          MACHINE="UNKNOWN"
esac

rm -rf $PKGDIR
cp -R /opt/wasi-sdk $PKGDIR
cd build
tar czf wasi-sdk-$VERSION\-$MACHINE.tar.gz wasi-sdk-$VERSION

# As well as the full SDK package, also create archives of libclang_rt.builtins
# and the sysroot. These are made available for users who have an existing clang
# installation.
tar czf libclang_rt.builtins-wasm32-wasi-$VERSION.tar.gz -C compiler-rt lib/wasi
tar czf wasi-sysroot-$VERSION.tar.gz -C wasi-sdk-$VERSION/share wasi-sysroot

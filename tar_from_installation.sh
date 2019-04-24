#!/usr/bin/env bash
set -ex
if [ -n "$1" ]; then
	export VERSION="$1"
else
	export VERSION=`./version.sh`
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
mkdir -p $PKGDIR/opt
cp -R /opt/wasi-sdk $PKGDIR/opt/
cd build &&
tar czf wasi-sdk-$VERSION\-$MACHINE.tar.gz wasi-sdk-$VERSION &&
tar cz -C compiler-rt -f libclang_rt.builtins-wasm32-wasi-$VERSION.tar.gz lib/wasi

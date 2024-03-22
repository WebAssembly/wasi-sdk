#!/usr/bin/env bash
set -ex

if [ -n "$1" ]; then
    OUTDIR=$1
else
    OUTDIR=$PWD/dist
fi

if [ -n "$2" ]; then
    VERSION="$2"
else
    VERSION=`./version.py`
fi

if [ -n "$3" ]; then
    INSTALL_DIR="$3"
else
    INSTALL_DIR=/opt/wasi-sdk
fi

case "$(uname -s)" in
    Linux*)     MACHINE=linux;;
    Darwin*)    MACHINE=macos;;
    CYGWIN*)    MACHINE=cygwin;;
    MINGW*)     MACHINE=mingw;;
    MSYS*)      MACHINE=msys;; #MSYS_NT-10.0-19043
    *)          MACHINE="UNKNOWN"
esac

if [ ! -d $INSTALL_DIR ] ; then
    echo "Directory $INSTALL_DIR doesn't exist.  Nothing to copy from."
    exit 1
fi

PKGDIR=build/wasi-sdk-$VERSION
rm -rf $PKGDIR
if [ "$MACHINE" == "cygwin" ] || [ "$MACHINE" == "mingw" ] || [ "$MACHINE" == "msys" ]; then
    # Copy with -L to avoid trying to create symlinks on Windows.
    cp -R -L $INSTALL_DIR $PKGDIR
else
    cp -R $INSTALL_DIR $PKGDIR
fi
cd build
tar czf $OUTDIR/wasi-sdk-$VERSION\-$MACHINE.tar.gz wasi-sdk-$VERSION

# As well as the full SDK package, also create archives of libclang_rt.builtins
# and the sysroot. These are made available for users who have an existing clang
# installation.
tar czf $OUTDIR/libclang_rt.builtins-wasm32-wasi-$VERSION.tar.gz -C compiler-rt lib/wasi
tar czf $OUTDIR/wasi-sysroot-$VERSION.tar.gz -C wasi-sdk-$VERSION/share wasi-sysroot

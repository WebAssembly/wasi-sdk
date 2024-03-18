#!/usr/bin/env sh
set -x

command -v dpkg-deb >/dev/null
if [ $? -ne 0 ]; then
    echo "required tool dpkg-deb missing. exiting"
    exit 0
fi

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

if [ ! -d $INSTALL_DIR ] ; then
    echo "Directory $INSTALL_DIR doesn't exist. Nothing to copy from."
    exit 1
fi

ARCH=$(dpkg --print-architecture)

rm -rf build/pkg
mkdir -p build/pkg/opt
mkdir -p build/pkg/DEBIAN
sed -e s/VERSION/$VERSION/ wasi-sdk.control > build/pkg/DEBIAN/control
cp -R $INSTALL_DIR build/pkg/opt/
cd build && dpkg-deb -b pkg wasi-sdk_$VERSION\_$ARCH\.deb && cd ..
mv build/wasi-sdk_$VERSION\_$ARCH\.deb $OUTDIR/

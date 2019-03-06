#!/usr/bin/env sh
set -ex
if [ -n "$1" ]; then
	export VERSION="$1"
else
	export VERSION=`./version.sh`
fi

rm -rf build/pkg
mkdir -p build/pkg/opt
mkdir -p build/pkg/DEBIAN
sed -e s/VERSION/$VERSION/ wasi-sdk.control > build/pkg/DEBIAN/control
cp -R /opt/wasi-sdk build/pkg/opt/
cd build && dpkg-deb -b pkg wasi-sdk_$VERSION\_amd64.deb

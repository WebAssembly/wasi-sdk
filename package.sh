#!/usr/bin/env sh

if [ -n "$1" ]; then
	export VERSION="$1"
else
	export VERSION=`./version.sh`
fi

rm -rf pkg
mkdir -p pkg/opt
mkdir pkg/DEBIAN
sed -e s/VERSION/$VERSION/ wasi-sdk.control > pkg/DEBIAN/control
cp -R /opt/wasi-sdk pkg/opt/
dpkg-deb -b pkg wasi-sdk_$VERSION\_amd64.deb
rm -rf pkg

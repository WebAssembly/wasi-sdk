#!/bin/bash

# Helper script executed on CI once all builds have completed. This takes
# `wasi-toolchain-*` artifacts and `wasi-sysroot-*` artifacts and merges
# them together into a single `wasi-sdk-*` artifact. Toolchains which don't
# have a sysroot that they themselves built use a sysroot from the x86_64-linux
# toolchain.

set -ex

rm -rf dist
mkdir dist
version=$(./version.py)

# Array of experimental release prefixes to strip
experimental_prefixes=("experimental-threading-")

# Strip matching prefix if found
matched_prefix=""
for prefix in "${experimental_prefixes[@]}"; do
  if [[ $version == $prefix* ]]; then
    matched_prefix=${prefix%-}  # Remove trailing dash from prefix
    version=${version#$prefix}
    break
  fi
done

make_deb() {
  build=$1
  dir=$2

  if ! command -v dpkg-deb >/dev/null; then
    return
  fi

  case $build in
    dist-x86_64-linux)  deb_arch=amd64   ;;
    dist-arm64-linux)   deb_arch=arm64   ;;
    dist-riscv64-linux) deb_arch=riscv64 ;;
    *)
      echo "unknown build $build"
      exit 1
  esac

  mkdir dist/pkg
  mkdir dist/pkg/opt
  mkdir dist/pkg/DEBIAN
  sed "s/Package: wasi-sdk$/Package: wasi-sdk${matched_prefix:+-$matched_prefix}/" wasi-sdk.control | \
    sed s/VERSION/$version/ | \
    sed s/ARCH/$deb_arch/ > dist/pkg/DEBIAN/control
  cp -R $dir dist/pkg/opt/wasi-sdk
  deb_name=$(echo $(basename $dir) | sed 's/.tar.gz//')
  (cd dist && dpkg-deb -b pkg $deb_name.deb)
  rm -rf dist/pkg
}

for build in dist-*; do
  toolchain=`ls $build/wasi-toolchain-*`
  sdk_dir=`basename $toolchain | sed 's/.tar.gz//' | sed s/toolchain/sdk/`
  mkdir dist/$sdk_dir
  tar xf $toolchain -C dist/$sdk_dir --strip-components 1
  tar czf dist/$sdk_dir.tar.gz -C dist $sdk_dir
  if echo $build | grep -q linux; then
    make_deb $build dist/$sdk_dir
  fi
  rm -rf dist/$sdk_dir
done

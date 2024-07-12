#!/bin/sh

# Helper script executed on CI once all builds have completed. This takes
# `wasi-toolchain-*` artifacts and `wasi-sysroot-*` artifacts and merges
# them together into a single `wasi-sdk-*` artifact. Toolchains which don't
# have a sysroot that they themselves built use a sysroot from the x86_64-linux
# toolchain.

set -ex

rm -rf dist
mkdir dist
version=$(./version.py)

make_deb() {
  build=$1
  dir=$2

  if ! command -v dpkg-deb >/dev/null; then
    return
  fi

  case $build in
    dist-x86_64-linux) deb_arch=amd64 ;;
    dist-arm64-linux)  deb_arch=arm64 ;;
    *)
      echo "unknown build $build"
      exit 1
  esac

  mkdir dist/pkg
  mkdir dist/pkg/opt
  mkdir dist/pkg/DEBIAN
  sed s/VERSION/$version/ wasi-sdk.control | \
    sed s/ARCH/$deb_arch/ > dist/pkg/DEBIAN/control
  cp -R $dir dist/pkg/opt/wasi-sdk
  deb_name=$(echo $(basename $dir) | sed 's/.tar.gz//')
  (cd dist && dpkg-deb -b pkg $deb_name.deb)
  rm -rf dist/pkg
}

for build in dist-*; do
  toolchain=`ls $build/wasi-toolchain-*`
  if [ -f $build/wasi-sysroot-* ]; then
    sysroot=`ls $build/wasi-sysroot-*`
  else
    sysroot=`ls dist-x86_64-linux/wasi-sysroot-*`
  fi
  if [ -f $build/libclang_rt* ]; then
    compiler_rt=`ls $build/libclang_rt*`
  else
    compiler_rt=`ls dist-x86_64-linux/libclang_rt*`
  fi

  sdk_dir=`basename $toolchain | sed 's/.tar.gz//' | sed s/toolchain/sdk/`
  mkdir dist/$sdk_dir

  # Start with the toolchain and then overlay the sysroot into
  # `share/wasi-sysroot`, the default sysroot.
  tar xf $toolchain -C dist/$sdk_dir --strip-components 1
  mkdir -p dist/$sdk_dir/share/wasi-sysroot
  tar xf $sysroot -C dist/$sdk_dir/share/wasi-sysroot --strip-components 1

  # Setup the compiler-rt library for wasi,wasip1,wasip2
  rtlibdir=$(dirname $(find dist/$sdk_dir/lib -name include))/lib
  mkdir -p $rtlibdir/wasi
  tar xf $compiler_rt -C $rtlibdir/wasi --strip-components 1
  cp -r $rtlibdir/wasi $rtlibdir/wasip1
  cp -r $rtlibdir/wasi $rtlibdir/wasip2

  tar czf dist/$sdk_dir.tar.gz -C dist $sdk_dir

  if echo $build | grep -q linux; then
    make_deb $build dist/$sdk_dir
  fi
  rm -rf dist/$sdk_dir
done

# In addition to `wasi-sdk-*` also preserve artifacts for just the sysroot
# and just compiler-rt.
if [ -d dist-x86_64-linux ]; then
  cp dist-x86_64-linux/wasi-sysroot-* dist
  cp dist-x86_64-linux/libclang_rt* dist
fi

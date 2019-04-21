#!/bin/bash
set -e
sudo apt update
# from the Dockerfile
sudo apt install -y --no-install-recommends \
	build-essential \
	clang \
	cmake \
	python \
	git \
	ninja-build
# we're sudo'ing since we need to write to /opt
sudo make package
cp build/wasi-sdk-*.tar.gz build/wasi-sdk-*.deb "$BUILD_ARTIFACTSTAGINGDIRECTORY/"

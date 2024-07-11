# About

This folder contains the docker images that are used in CI to build the wasi-sdk
release toolchains. Docker is used to intentionally use older Linux
distributions to build the toolchain to have a more maximal set of glibc
compatibility.

These images are intended to be used on an x86\_64 host. Images start from the
`Dockerfile.common` file and then layer on target-specific
toolchains/options/etc as necessary.

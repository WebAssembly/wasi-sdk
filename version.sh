#!/usr/bin/env bash
set -e
GIT_DESCR=$(git describe --long --candidates=999 --match='wasi-sdk-*' --dirty='+m' --abbrev=12)
GIT_PACKAGE_VERSION=$(echo $GIT_DESCR | perl -ne 'if(/^wasi-sdk-(\d+)-(\d+)-g([0-9a-f]{7,12})([+]m)?$/) { print "$1.$2g$3$4"; exit } else { print "could not parse git description"; exit 1 }';)
echo $GIT_PACKAGE_VERSION

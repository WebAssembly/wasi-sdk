#!/usr/bin/env bash
set -e
git config --global --add safe.directory "/workspace"
GIT_DESCR=$(git describe --long --candidates=999 --match='wasi-sdk-*' --dirty='+m' --abbrev=12)
GIT_PACKAGE_VERSION=$(echo $GIT_DESCR | perl -ne 'if(/^wasi-sdk-(\d+)([+].+)?-(\d+)-g([0-9a-f]{7,12})([+]m)?$/) { if($3 == 0) { print "$1.$3$5$2" } else { print "$1.$3g$4$5$2" } exit } else { print "could not parse git description"; exit 1 }';)
echo $GIT_PACKAGE_VERSION

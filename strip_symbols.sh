#!/usr/bin/env bash
set -e

DIRECTORY=${1:-/opt/wasi-sdk/bin}
if [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "freebsd"* ]]; then
# macos and freebsd find do not support -executable so we fall back on
# having a permission bit to execute:
EXECUTABLES=$(find ${DIRECTORY} -type f -perm +111)
else
EXECUTABLES=$(find ${DIRECTORY} -type f -executable)
fi
for e in ${EXECUTABLES}; do
  echo "Stripping symbols: ${e}"
  strip ${e} || echo "Failed to strip symbols for ${e}; continuing on."
done

#!/usr/bin/env sh
set -e

DIRECTORY=${1:-/opt/wasi-sdk/bin}
EXECUTABLES=$(find ${DIRECTORY} -type f -executable)
for e in ${EXECUTABLES}; do
  echo "Stripping symbols: ${e}"
  strip ${e} || echo "Failed to strip symbols for ${e}; continuing on."
done

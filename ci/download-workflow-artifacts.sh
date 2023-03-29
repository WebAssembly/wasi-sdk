#!/usr/bin/env bash
set -e

# This script downloads and unzips the artifacts produced in a workflow run. The
# script has several pre-requisites:
# - some standard Bash tools (curl, unzip) and one slightly more rare one (jq)
# - the ID of a workflow run that has run successfully--this is where we
#   retrieve the artifacts from
# - a GitHub access token, see https://github.com/settings/tokens
#
# Usage: download-workflow-artifacts.sh <workflow run ID> <token>

WORKFLOW_RUN_ID=$1
GITHUB_TOKEN=$2
GITHUB_API_VERSION=2022-11-28
GITHUB_API_URL=https://api.github.com/repos/WebAssembly/wasi-sdk
TMP_DIR=$(mktemp -d -t wasi-sdk-artifacts.XXXXXXX)

if [ -z "${WORKFLOW_RUN_ID}" ] || [ -z "${GITHUB_TOKEN}" ]; then
    >&2 echo "Missing parameter; exiting..."
    >&2 echo "Usage: download-worfklow-artifacts.sh <workflow run ID> <token>"
    exit 1
fi

# List out the artifacts in the given workflow run.
# See https://docs.github.com/en/rest/actions/artifacts#list-workflow-run-artifacts
ARTIFACTS=$(curl \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "X-GitHub-Api-Version: ${GITHUB_API_VERSION}" \
    "${GITHUB_API_URL}/actions/runs/${WORKFLOW_RUN_ID}/artifacts" \
        | jq -r '.artifacts[] | [(.id|tostring), .name, .archive_download_url] | join(",")')

for A in $ARTIFACTS; do
    ID=$(echo $A | cut -d ',' -f 1)
    NAME=$(echo $A | cut -d ',' -f 2)
    URL=$(echo $A | cut -d ',' -f 3)
    TO=$TMP_DIR/$NAME.zip
    # Exclude dist-ubuntu-latest to prefer dist-ubuntu-bionic, which is
    # compatible with wider distributions. See:
    # - https://github.com/WebAssembly/wasi-sdk/pull/273#issuecomment-1373879491
    # - https://github.com/WebAssembly/wasi-sdk/issues/303
    if [ "${NAME}" = "dist-ubuntu-latest" ]; then
        continue
    fi
    >&2 echo "===== Downloading: ${TO} ====="

    # Download the artifacts to the temporary directory.
    # See https://docs.github.com/en/rest/actions/artifacts#download-an-artifact
    curl \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "X-GitHub-Api-Version: ${GITHUB_API_VERSION}" \
        --location --output "${TO}" \
        "${GITHUB_API_URL}/actions/artifacts/${ID}/zip"
done

# Unzip the workflow artifacts into a `release` directory.
pushd $TMP_DIR > /dev/null
mkdir release
ls -1 *.zip | xargs -n1 unzip -q -o -d release
# Some explanation:
#   -1 prints each file on a separate line
#   -n1 runs the command once for each item
#   -q means quietly
#   -o allows unzip to overwrite existing files (e.g., multiple copies of `libclang_rt.builtins-wasm32-wasi-...`)
#   -d tells unzip which directory to place things in
>&2 echo "===== Files to release: ${TMP_DIR}/release ====="
>&2 ls -1 release
popd > /dev/null

>&2 echo
>&2 echo "Ensure the above artifacts look correct, then run \`draft-release.sh\` with the following directory:"
echo "${TMP_DIR}/release"

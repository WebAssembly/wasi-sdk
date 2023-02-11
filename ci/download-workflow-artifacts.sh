#!/usr/bin/env bash
set -e

# This script downloads and unzips the artifacts produced in a workflow run. It
# also checks that the workflow commit corresponds to the tag commit that these
# artifacts will be released under. The script has several pre-requisites:
# - some standard Bash tools (curl, unzip) and one slightly more rare one (jq)
# - an already-created tag in the repository (this marks the code to release)
# - the ID of a workflow run that has run successfully--this is where we
#   retrieve the artifacts from
# - a GitHub access token, see https://github.com/settings/tokens
#
# Usage: download-workflow-artifacts.sh <release tag> <workflow run ID> <token>

TAG=$1
WORKFLOW_RUN_ID=$2
GITHUB_TOKEN=$3
GITHUB_API_VERSION=2022-11-28
GITHUB_API_URL=https://api.github.com/repos/WebAssembly/wasi-sdk
TMP_DIR=$(mktemp -d -t wasi-sdk-artifacts.XXXXXXX)

if [ -z "${TAG}" ] || [ -z "${WORKFLOW_RUN_ID}" ] || [ -z "${GITHUB_TOKEN}" ]; then
    >&2 echo "Missing parameter; exiting..."
    >&2 echo "Usage: download-worfklow-artifacts.sh <release tag> <workflow run ID> <token>"
    exit 1
fi

# Get the commit SHA for the passed tag.
# See https://docs.github.com/en/rest/commits/commits#get-a-commit
MATCHING_COMMIT=$(curl \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "X-GitHub-Api-Version: ${GITHUB_API_VERSION}" \
    "${GITHUB_API_URL}/commits/${TAG}")
COMMIT=$(echo $MATCHING_COMMIT  | jq -r '.sha')
>&2 echo "===== Found commit for tag ${TAG}: ${COMMIT} ====="

# Check that the commit of the workflow run matches the tag commit and that the
# workflow was successful.
# See https://docs.github.com/en/rest/actions/workflow-runs#get-a-workflow-run
WORKFLOW_RUN=$(curl \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "X-GitHub-Api-Version: ${GITHUB_API_VERSION}" \
    "${GITHUB_API_URL}/actions/runs/${WORKFLOW_RUN_ID}")
WORKFLOW_COMMIT=$(echo $WORKFLOW_RUN | jq -r '.head_sha')
WORKFLOW_STATUS=$(echo $WORKFLOW_RUN | jq -r '.status')
>&2 echo "===== Found commit for workflow ${WORKFLOW_RUN_ID}: ${WORKFLOW_COMMIT} ====="
if [ "${COMMIT}" != "${WORKFLOW_COMMIT}" ]; then
    >&2 echo "Commit at tag ${TAG} did not match the commit for workflow ${WORKFLOW_RUN_ID}, exiting...:"
    >&2 echo "  ${COMMIT} != ${WORKFLOW_COMMIT}"
    exit 1
fi
if [ "${WORKFLOW_STATUS}" != "completed" ]; then
    >&2 echo "Workflow ${WORKFLOW_RUN_ID} did not end successfully, exiting...:"
    >&2 echo "  status = ${WORKFLOW_STATUS}"
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

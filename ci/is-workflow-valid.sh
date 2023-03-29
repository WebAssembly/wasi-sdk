#!/usr/bin/env bash
set -e

# This script checks 1) that the workflow commit corresponds to the commit for
# the given tag and 2) that the workflow has completed. This is a sanity check
# to ensure the artifacts we are about to publish are in fact built from the
# commit/tag we think. The script has several pre-requisites:
# - some standard Bash tools (curl, unzip) and one slightly more rare one (jq)
# - an already-created tag in the repository (this marks the code to release)
# - the ID of a workflow run that has run successfully--this is where we
#   retrieve the artifacts from
# - a GitHub access token, see https://github.com/settings/tokens
#
# Usage: is-workflow-valid.sh <release tag> <workflow run ID> <token>

TAG=${TAG:-$1}
WORKFLOW_RUN_ID=${WORKFLOW_RUN_ID:-$2}
GITHUB_TOKEN=${GITHUB_TOKEN:-$3}
GITHUB_API_VERSION=${GITHUB_API_VERSION:-2022-11-28}
GITHUB_API_URL=${GITHUB_API_URL:-https://api.github.com/repos/WebAssembly/wasi-sdk}

if [ -z "${TAG}" ] || [ -z "${WORKFLOW_RUN_ID}" ] || [ -z "${GITHUB_TOKEN}" ]; then
    >&2 echo "Missing parameter; exiting..."
    >&2 echo "Usage: is-workflow-valid.sh <release tag> <workflow run ID> <token>"
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

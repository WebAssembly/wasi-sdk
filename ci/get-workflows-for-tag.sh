#!/usr/bin/env bash
set -e

# This script retrieves a list of GitHub workflow runs that have successfully completed for a given
# Git tag. The list is printed to stdout (all other output to stderr). It has several
# pre-requisites:
# - some standard Bash tools (curl) and one slightly more rare one (jq)
# - an already-created tag in the repository (this marks the code to release)
# - a GitHub access token, see https://github.com/settings/tokens
#
# Usage: get-workflows-for-tag.sh <tag> <token>

TAG=$1
GITHUB_TOKEN=$2
GITHUB_API_VERSION=2022-11-28
GITHUB_API_URL=https://api.github.com/repos/WebAssembly/wasi-sdk

if [ -z "${TAG}" ] || [ -z "${GITHUB_TOKEN}" ]; then
    >&2 echo "Missing parameter; exiting..."
    >&2 echo "Usage: get-workflows-for-tag.sh <tag> <token>"
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

# Find the workflow runs matching the tag commit.
# See https://docs.github.com/en/rest/actions/workflow-runs#list-workflow-runs-for-a-repository
MATCHING_WORKFLOWS=$(curl \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "X-GitHub-Api-Version: ${GITHUB_API_VERSION}" \
    "${GITHUB_API_URL}/actions/runs?head_sha=${COMMIT}&status=success")
WORKFLOW_RUN_IDS=$(echo $MATCHING_WORKFLOWS | jq -r '.workflow_runs[].id')
>&2 echo "===== Matching workflow run IDs: ====="
echo "$WORKFLOW_RUN_IDS"

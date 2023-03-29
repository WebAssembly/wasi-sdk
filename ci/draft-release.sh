#!/usr/bin/env bash
set -e

# This script creates a draft pre-release with the artifacts produced in a
# workflow run (see `download-workflow-artifacts.sh`). Note that the pre-release
# is not published publicly--this is kept as a manual step as a safeguard. The
# script has several pre-requisites:
# - some standard Bash tools (curl, unzip) and one slightly more rare one (jq)
# - an already-created tag in the repository (this marks the code to release)
# - a directory containing the artifacts to attach to the release.
# - a GitHub access token, see https://github.com/settings/tokens
#
# Usage: draft-release.sh <release tag> <artifacts dir> <token>

TAG=${TAG:-$1}
ARTIFACTS_DIR=${ARTIFACTS_DIR:-$2}
GITHUB_TOKEN=${GITHUB_TOKEN:-$3}
GITHUB_API_VERSION=${GITHUB_API_VERSION:-2022-11-28}
GITHUB_API_URL=${GITHUB_API_URL:-https://api.github.com/repos/WebAssembly/wasi-sdk}
TMP_DIR=$(mktemp -d -t release.sh.XXXXXXX)

if [ -z "${TAG}" ] || [ -z "${ARTIFACTS_DIR}" ] || [ -z "${GITHUB_TOKEN}" ]; then
    >&2 echo "Missing parameter; exiting..."
    >&2 echo "Usage: draft-release.sh <release tag> <artifacts dir> <token>"
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

# Create a draft pre-release for this commit.
# See https://docs.github.com/en/rest/releases/releases#create-a-release
RELEASE_JSON=$(curl \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}"\
    -H "X-GitHub-Api-Version: ${GITHUB_API_VERSION}" \
    "${GITHUB_API_URL}/releases" \
    -d '{"tag_name":"'${TAG}'","target_commitish":"'${COMMIT}'","name":"'${TAG}'","draft":true,"prerelease":true,"generate_release_notes":true}')
UPLOAD_URL=$(echo $RELEASE_JSON | jq -r '.upload_url')
# Remove the "helpful" but invalid URL suffix that GitHub adds:
UPLOAD_URL=${UPLOAD_URL/\{?name,label\}}
HTML_URL=$(echo $RELEASE_JSON | jq -r '.html_url')
>&2 echo "===== Created draft release: ${HTML_URL} ====="

# Upload the unzipped artifact files to the release.
# See https://docs.github.com/en/rest/releases/assets#upload-a-release-asset
for FILE in $(ls "${ARTIFACTS_DIR}"); do
    FROM=$ARTIFACTS_DIR/$FILE
    >&2 echo "===== Uploading: ${FROM} ====="
    UPLOADED=$(curl \
        -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${GITHUB_TOKEN}"\
        -H "X-GitHub-Api-Version: ${GITHUB_API_VERSION}" \
        -H "Content-Type: application/octet-stream" \
        "${UPLOAD_URL}?name=${FILE}" \
        --data-binary "@${FROM}")
done

>&2 echo
>&2 echo "===== Completed ====="
>&2 echo "This created a draft release, do not forget to manually publish it at:"
echo "${HTML_URL}"

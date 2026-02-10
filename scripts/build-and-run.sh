#!/usr/bin/env bash

set -euo pipefail

# Expected input (auto-populated when in GitHub Actions)
: "${GITHUB_WORKSPACE:=}"
: "${GITHUB_API_URL:=}"
: "${GITHUB_SERVER_URL:=}"
: "${GITHUB_WORKFLOW:=}"
: "${GITHUB_JOB:=}"
: "${GITHUB_REF:=}"
: "${GITHUB_REPOSITORY:=}"
: "${GITHUB_RUN_ID:=}"
: "${GITHUB_SHA:=}"
: "${GITHUB_TOKEN:=}"

# Debugging helper.
if [[ ${GITHUB_ACTIONS:-false} == "true" ]]; then
  echo "::group::GITHUB_ environment variables"
  env | grep GITHUB_
  echo "::endgroup::"
fi

echo "Building... this may take a while..."
# GitHub Actions -specific
: "${ACTIONS_CACHE_URL:=}"
: "${ACTIONS_RUNTIME_TOKEN:=}"
export ACTIONS_CACHE_URL=${ACTIONS_CACHE_URL}
export ACTIONS_RUNTIME_TOKEN=${ACTIONS_RUNTIME_TOKEN}

BUILDX_BUILDER="gha-builder"
export BUILDX_BUILDER
if ! docker buildx inspect "${BUILDX_BUILDER}" >/dev/null 2>&1; then
  docker buildx create \
    --driver docker-container \
    --bootstrap \
    --name "${BUILDX_BUILDER}" \
    --use
else
  docker buildx use "${BUILDX_BUILDER}"
fi

if [[ ${GITHUB_ACTIONS:-false} == "true" ]]; then
  DOCKER_LOAD_PUSH="--push --cache-from type=gha --cache-to type=gha,mode=max"
else
  DOCKER_LOAD_PUSH="--load"
fi

# shellcheck disable=SC2248 # I want no double quoting
DOCKER_BUILD=$(
  docker buildx build \
    --quiet \
    --build-arg "workdir=${PWD}" \
    --tag rebar-dependency-submission:latest \
    ${DOCKER_LOAD_PUSH} \
    . ||
    exit $?
)
echo "Done!"
echo ""

#docker run \
#  --volume ".:${GITHUB_WORKSPACE}" \
#  --workdir "${GITHUB_WORKSPACE}" \
#  --env GITHUB_API_URL="${GITHUB_API_URL}" \
#  --env GITHUB_SERVER_URL="${GITHUB_SERVER_URL}" \
#  --env GITHUB_WORKFLOW="${GITHUB_WORKFLOW}" \
#  --env GITHUB_JOB="${GITHUB_JOB}" \
#  --env GITHUB_REF="${GITHUB_REF}" \
#  --env GITHUB_REPOSITORY="${GITHUB_REPOSITORY}" \
#  --env GITHUB_RUN_ID="${GITHUB_RUN_ID}" \
#  --env GITHUB_SHA="${GITHUB_SHA}" \
#  --env GITHUB_TOKEN="${GITHUB_TOKEN}" \
#  "${DOCKER_BUILD}" \
#  "$@"

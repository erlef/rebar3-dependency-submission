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
: "${GITHUB_WORKSPACE:=}"

echo "Building... this may take a while..."
docker build --build-arg "workdir=${PWD}" . || exit $?
echo "Done!"

echo "Running... this may take a while..."
DOCKER_BUILD=$(docker build -qq .)
docker run \
  --volume ".:${GITHUB_WORKSPACE}" \
  --workdir "${GITHUB_WORKSPACE}" \
  --env GITHUB_API_URL="${GITHUB_API_URL}" \
  --env GITHUB_SERVER_URL="${GITHUB_SERVER_URL}" \
  --env GITHUB_WORKFLOW="${GITHUB_WORKFLOW}" \
  --env GITHUB_JOB="${GITHUB_JOB}" \
  --env GITHUB_REF="${GITHUB_REF}" \
  --env GITHUB_REPOSITORY="${GITHUB_REPOSITORY}" \
  --env GITHUB_RUN_ID="${GITHUB_RUN_ID}" \
  --env GITHUB_SHA="${GITHUB_SHA}" \
  --env GITHUB_TOKEN="${GITHUB_TOKEN}" \
  --env GITHUB_WORKSPACE="${GITHUB_WORKSPACE}" \
  "${DOCKER_BUILD}" \
  "$@"
echo "Done!"

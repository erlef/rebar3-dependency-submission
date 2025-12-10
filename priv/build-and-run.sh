#!/bin/sh

docker build --build-arg "workdir=$PWD" . || exit $?
echo "Build done, running..."

docker run \
    --volume ".:$GITHUB_WORKSPACE" \
    --workdir "$GITHUB_WORKSPACE" \
    --env GITHUB_API_URL \
    --env GITHUB_SERVER_URL \
    --env GITHUB_WORKFLOW \
    --env GITHUB_JOB \
    --env GITHUB_REF \
    --env GITHUB_REPOSITORY \
    --env GITHUB_RUN_ID \
    --env GITHUB_SHA \
    --env GITHUB_TOKEN \
    --env GITHUB_WORKSPACE \
    "$(docker build -qq .)" \
    $@

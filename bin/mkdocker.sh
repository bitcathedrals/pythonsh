#! /usr/bin/env bash

template=docker/Dockerfile.template

DOCKER_VERSION=$1
TIMESTAMP=$2

sed <$template -e "s,@DOCKER_VERSION@,${DOCKER_VERSION},g" | sed -e "s,@TIMESTAMP@,${TIMESTAMP},g"

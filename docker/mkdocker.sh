#! /usr/bin/env bash

script=`dirname $0`
template=${script}/Dockerfile.template

DOCKER_VERSION=$1
PYTHON_VERSION=$2
TIMESTAMP=$3

sed <$template -e "s,@DOCKER_VERSION@,${DOCKER_VERSION},g" |\
  sed -e "s,@PYTHON_VERSION@,${PYTHON_VERSION},g" |\
  sed -e "s,@TIMESTAMP@,${TIMESTAMP},g"

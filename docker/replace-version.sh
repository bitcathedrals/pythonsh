#! /usr/bin/env bash

source $1
sed <Dockerfile.python -e "s,@VERSION@,${DOCKER_VERSION},g" >Dockerfile

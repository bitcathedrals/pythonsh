#! /usr/bin/env bash

script=`dirname $0`
script="${script}/virtualenv-runner.sh"

ENV=$1

if [[ -z $ENV ]]
then
  echo >/dev/stderr "mkrunner.sh: no ENV given as arg(1). exiting."
  exit 1
fi

if [[ $ENV == "none" ]]
then
  ENV=""
fi

sed <$script -e "s,@DEFAULT@,\"$ENV\",g"

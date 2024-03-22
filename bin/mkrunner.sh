#! /usr/bin/env bash

script=`dirname $0`
script="${script}/virtualenv-runner.sh"

ENV=$1

if [[ -n $ENV ]]
then
  ENV=$1
  shift
else
  echo >/dev/stderr "mkrunner.sh: pyenv environment must be the first arg. exiting."
  exit 1
fi

if [[ -n $1 ]]
then
  HARDCODE="$*"
else
  echo >/dev/stderr "mkrunner.sh pyenv command plus optional arguments must be the second arg. exiting."
  exit 1
fi


sed <$script -e "s,@DEFAULT@,\"$ENV\",g" | sed -e "s,@HARDCODE@,$HARDCODE,g"

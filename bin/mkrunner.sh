#! /usr/bin/env bash

script=`dirname $0`
script="${script}/virtualenv-runner.sh"

ENV=$1
shift

if [[ $1 == "help" ]]
then
  cat <<HELP
mkrunner.sh: <virtualenv> <program and args>*

Make a runner script that sets the venv, runs the command, and then restores the previous environment.

HELP
fi

if [[ -z $ENV ]]
then
  echo >/dev/stderr "mkrunner.sh: pyenv environment must be the first arg. exiting."
  exit 1
fi

sed <$script -e "s,@VENV@,\"$ENV\",g" | sed -e "s,@HARDCODE@,$*,g"

#! /usr/bin/env bash

script=`dirname $0`
script="${script}/virtualenv-runner.sh"

ENV=$1
shift

# , and then restores the previous environment.

if [[ $1 == "help" ]]
then
  cat <<HELP
mkrunner.sh: <virtualenv> <program and args>*

Make a runner script that sets the venv and runs the command.
HELP
fi

if [[ -z $ENV ]]
then
  echo >/dev/stderr "mkrunner.sh: pyenv environment must be the first arg. exiting."
  exit 1
fi

sed <$script -e "s,@VENV@,\"$ENV\",g" | sed -e "s,@ENTRYPOINT@,$*,g"

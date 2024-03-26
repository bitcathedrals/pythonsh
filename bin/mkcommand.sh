#! /usr/bin/env bash

script=`dirname $0`
script="${script}/virtualenv-command.sh"

if [[ -z $1 ]]
then
  echo >/dev/stderr "mkcommand.sh pyenv environment must be the sole argument. exiting."
  exit 1
fi

sed <$script -e "s,@VENV@,$1,g"

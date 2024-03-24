#! /usr/bin/env bash

script=`dirname $0`
script="${script}/virtualenv-launcher.sh"

if [[ -n $1 ]]
then
  ENTRYPOINT="$*"
else
  echo >/dev/stderr "mkrunner.sh pyenv command plus optional arguments must be the second arg. exiting."
  exit 1
fi

sed <$script -e "s,@ENTRYPOINT@,$ENTRYPOINT,g"

#! /usr/bin/env bash

script=`dirname $0`
script="${script}/virtualenv-launcher.sh"

if [[ $1 == "help" ]]
then
  cat <<HELP
mklauncher.sh virtualenv program-args*

create a script that launches a program in the <virtualenv> given.

- The first arg is the virtualenv.
- The rest of the args are command and any args that are hardcoded into the launcher.

The script is written to stdout.
HELP
  exit 0
fi

if [[ -z $1 ]]
then
  echo >/dev/stderr "mkrunner.sh USER = (1) virtualenv = arg(2) (rest) = arguments. exiting."
  exit 1
fi

venv=$1
shift

if [[ -z $1 ]]
then
  echo >/dev/stderr "mkrunner.sh user = (1) VIRTUALENV = arg(2) plus (rest) = arguments. exiting."
  exit 1
fi

user=$1
shift

entry=$*

sed <$script -e "s,@VENV@,$venv,g" | sed -e "s,@ENTRYPOINT@,$entry,g" | sed -e "s,@USER@,$user,g"


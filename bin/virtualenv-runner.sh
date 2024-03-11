#! /usr/bin/env bash

ENV=${1:-@DEFAULT@}

if [[ -z $ENV ]]
then
  echo >/dev/stderr "virtual-runner.sh: no evironment was given! exiting."
  exit 1
fi

DEFAULT_PYPENV="$HOME/.pyenv/"
export PATH="$DEFAULT_PYENV:$PATH"

eval "$(pyenv init -)"

pyenv activate $ENV

if [[ $? -ne 0 ]]
then
  echo >/dev/stderr "virtual-runner.sh: pyenv activate $ENV failed! exiting."
  exit 1
fi

shift

exec pyenv exec @HARDCODE@ $@

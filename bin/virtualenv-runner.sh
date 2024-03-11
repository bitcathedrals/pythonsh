#! /usr/bin/env bash

DEFAULT_PYPENV="$HOME/.pyenv/"
export PATH="$DEFAULT_PYENV:$PATH"
ENV=$1

eval "$(pyenv init -)"

pyenv activate $ENV

if [[ $? -ne 0 ]]
then
  echo "pyenv activate $ENV FAILED!"
  exit 1
fi

shift

exec pyenv exec $@

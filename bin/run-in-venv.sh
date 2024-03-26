#! /usr/bin/env bash

VENV="$1"
shift

PYENV_ROOT="$HOME/.pyenv/"
export PATH="$PYENV_ROOT/bin:$PATH"

eval "$(pyenv init -)"

output=$(pyenv activate $VENV)

if [[ $? -ne 0 ]]
then
  echo >/dev/stderr "run-in-venv.sh: pyenv activate $VENV failed - $output exiting."
  exit 1
fi

exec $@

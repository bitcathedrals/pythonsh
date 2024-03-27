#! /usr/bin/env bash

VENV="$1"
shift

TOOLS=$HOME/tools
PYENV_ROOT="$TOOLS/pyenv"

PATH="$TOOLS/local/bin:$PATH"
PATH="$PYENV_ROOT/bin:$PATH"
PATH="$PYENV_ROOT/libexec:$PATH"

export PYENV_ROOT PATH

eval "$(pyenv init -)"

output=$(pyenv activate $VENV)

if [[ $? -ne 0 ]]
then
  echo >/dev/stderr "run-in-venv.sh: pyenv activate $VENV failed - $output exiting."
  exit 1
fi

exec $@

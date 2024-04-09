#! /usr/bin/env bash

VENV="$1"
shift

if [[ -z $VENV ]]
then
  echo "run-in-venv.sh: VENV arg(1) not specified. exiting."
  exit 1
fi

TOOLS=$HOME/tools
PYENV_ROOT="$TOOLS/pyenv"

PATH="$TOOLS/local/bin:$PATH"
PATH="$PYENV_ROOT/bin:$PATH"
PATH="$PYENV_ROOT/libexec:$PATH"

export PYENV_ROOT PATH

eval "$(pyenv init -)"

pyenv activate $VENV

if [[ $? -ne 0 ]]
then
  echo "run-in-venv.sh: pyenv activate $VENV failed - $output exiting."
  exit 1
fi

### CODE HERE ###

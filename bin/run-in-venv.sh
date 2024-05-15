#! /usr/bin/env bash

VENV="$1"
shift

TOOLS=$HOME/tools
PYENV_ROOT="$TOOLS/pyenv"

PATH="$TOOLS/local/bin:$PATH"
PATH="$PYENV_ROOT/bin:$PATH"
PATH="$PYENV_ROOT/libexec:$PATH"

export PYENV_ROOT PATH

echo "run-in-venv.sh: PATH = \"$PATH\""
echo "run-in-venv.sh: PYENV_ROOT = \"$PYENV_ROOT\""

eval "$(pyenv init -)"

pyenv activate $VENV

if [[ $? -ne 0 ]]
then
  echo "run-in-venv.sh: pyenv activate $VENV failed. exiting."
  exit 1
fi

exec $@

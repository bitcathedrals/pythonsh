#! /usr/bin/env bash

ENV="@VENV@"

TOOLS=$HOME/tools
PYENV_ROOT="$TOOLS/pyenv"
PATH="$TOOLS/local/bin:$PATH"
PATH="$PYENV_ROOT/bin:$PATH"
PATH="$PYENV_ROOT/libexec:$PATH"

export PYENV_ROOT PATH

eval "$(pyenv init -)"

pyenv activate $ENV

if [[ $? -ne 0 ]]
then
  echo >/dev/stderr "virtual-command.sh: pyenv activate $ENV failed! exiting."
  exit 1
fi

exec pyenv exec $@

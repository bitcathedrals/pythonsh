#! /usr/bin/env bash

TOOLS=$HOME/tools
export PATH="$TOOLS/local/bin:$TOOLS/pipenv/bin:$PATH"

ENV="@VENV@"

PYENV_ROOT="$HOME/.pyenv/"
export PATH="$PYENV_ROOT/bin:$PATH"

eval "$(pyenv init -)"

pyenv activate $ENV

if [[ $? -ne 0 ]]
then
  echo >/dev/stderr "virtual-command.sh: pyenv activate $ENV failed! exiting."
  exit 1
fi

exec pyenv exec $@

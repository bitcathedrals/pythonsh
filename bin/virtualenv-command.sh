#! /usr/bin/env bash

TOOLS=$HOME/tools
export PATH="$TOOLS/local/bin:$TOOLS/pipenv/bin:$PATH"

ENV="@VENV@"

PYENV_ROOT="$HOME/.pyenv/"

PATH="$PYENV_ROOT/bin:$PATH"
PATH="$PYENV_ROOT/libexec:$PATH"

export PYENV_ROOT PATH

eval "$(pyenv init -)"

output=$(pyenv activate $ENV)

if [[ $? -ne 0 ]]
then
  echo >/dev/stderr "virtual-command.sh: pyenv activate $ENV failed! - $output exiting."
  exit 1
fi

exec pyenv exec $@

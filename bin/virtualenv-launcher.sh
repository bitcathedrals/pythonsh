#! /bin/bash

TOOLS=$HOME/tools

VENV=@VENV@

PYENV_ROOT="$TOOLS/pyenv"
PATH="$TOOLS/local/bin:$PATH"
PATH="$PYENV_ROOT/bin:$PATH"
PATH="$PYENV_ROOT/libexec:$PATH"

export PYENV_ROOT PATH

eval "$(pyenv init -)"

pyenv activate $VENV

if [[ $? -ne 0 ]]
then
  echo >/dev/stderr "virtualenv-launcher.sh: unable to activate ${VENV}. exiting."
  exit 1
fi

exec pyenv exec @ENTRYPOINT@ $@


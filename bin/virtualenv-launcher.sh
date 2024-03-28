#! /bin/bash

TOOLS=$HOME/tools

PYENV_ROOT="$TOOLS/pyenv"
PATH="$TOOLS/local/bin:$PATH"
PATH="$PYENV_ROOT/bin:$PATH"
PATH="$PYENV_ROOT/libexec:$PATH"

export PYENV_ROOT PATH

VENV=@VENV@
USER=@USER@

su $USER

if [[ $? -ne 0 ]]
then
  echo >/dev/stderr "virtualenv-launcher.sh: unable to change user to ${USER}. exiting."
  exit 1
fi

eval "$(pyenv init -)"

pyenv activate $VENV

if [[ $? -ne 0 ]]
then
  echo >/dev/stderr "virtualenv-launcher.sh: unable to activate ${VENV}. exiting."
  exit 1
fi

exec pyenv exec @ENTRYPOINT@ $@


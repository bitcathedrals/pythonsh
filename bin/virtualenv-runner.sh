#! /usr/bin/env bash

VENV=@VENV@

TOOLS=$HOME/tools
PYENV_ROOT="$TOOLS/pyenv"
PATH="$TOOLS/local/bin:$PATH"
PATH="$PYENV_ROOT/bin:$PATH"
PATH="$PYENV_ROOT/libexec:$PATH"

export PYENV_ROOT PATH

eval "$(pyenv init -)"

RESTORE=""

if pyenv version | grep "system"
then
  pyenv activate $VENV
  if [[ $? -ne 0 ]]
  then
    echo >/dev/stderr "virtualenv-runner.sh: unable to activate ${ENVIRONMENT}. exiting."
    exit 1
  fi
else
  if pyenv version | grep -v "$VENV"
  then
    RESTORE=`pyenv version | cut -d ' ' -f 1`

    pyenv activate $VENV 2>&1

    if [[ $? -ne 0 ]]
    then
      echo >/dev/stderr "virtualenv-runner.sh: unable to activate ${VENV}. exiting."
      exit 1
    fi
  fi
fi

pyenv exec @ENTRYPOINT@ $@
exit_code=$?

if [[ -n $RESTORE ]]
then
  pyenv activate $RESTORE

  if [[ $? -ne 0 ]]
  then
    echo >/dev/stderr "virtualenv-runner.sh: unable to restore ${RESTORE}. exiting."
    exit 1
  fi
fi

exit $exit_code

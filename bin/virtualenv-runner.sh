#! /usr/bin/env bash

TOOLS=$HOME/tools
export PATH="$TOOLS/local/bin:$TOOLS/pipenv/bin:$PATH"

VENV=@VENV@

PYENV_ROOT="$HOME/.pyenv/"
export PATH="$PYENV_ROOT/bin:$PATH"

eval "$(pyenv init -)"

RESTORE=""

if pyenv version | grep "system"
then
  output=$(pyenv activate $VENV 2>&1)
  if [[ $? -ne 0 ]]
  then
    echo >/dev/stderr "virtualenv-runner.sh: unable to activate ${ENVIRONMENT} - $output. exiting."
    exit 1
  fi
else
  if pyenv version | grep -v "$VENV"
  then
    RESTORE=`pyenv version | cut -d ' ' -f 1`

    output=$(pyenv activate $VENV 2>&1)

    if [[ $? -ne 0 ]]
    then
      echo >/dev/stderr "virtualenv-runner.sh: unable to activate ${VENV} - $output. exiting."
      exit 1
    fi
  fi
fi

pyenv exec @ENTRYPOINT@ $@
exit_code=$?

if [[ -n $RESTORE ]]
then
  output=$(pyenv activate $RESTORE 2>&1)

  if [[ $? -ne 0 ]]
  then
    echo >/dev/stderr "virtualenv-runner.sh: unable to restore ${RESTORE} - $output. exiting."
    exit 1
  fi
fi

exit $exit_code

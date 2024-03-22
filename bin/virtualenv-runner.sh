#! /usr/bin/env bash

DEFAULT=@DEFAULT@
ARG=$1

ENVIRONMENT=""

if [[ -n $DEFAULT ]]
then
  ENVIRONMENT=$DEFAULT
else
  if [[ -z $ARG ]]
  then
    echo >/dev/stderr "virtualenv-runner.sh: no environment arg given! exiting."
    exit 1
  fi

  ENVIRONMENT=$ARG
  shift
fi

DEFAULT_PYENV="$HOME/.pyenv/"
export PATH="$DEFAULT_PYENV:$PATH"

eval "$(pyenv init -)"

RESTORE=""

if pyenv version | grep "system"
then
  pyenv activate $ENVIRONMENT >/dev/null 2>&1
  if [[ $? -ne 0 ]]
  then
    echo >/dev/stderr "virtualenv-runner.sh: unable to activate ${ENVIRONMENT}. exiting."
    exit 1
  fi
else
  if pyenv version | grep -v "$ENVIRONMENT"
  then
    RESTORE=`pyenv version | cut -d ' ' -f 1`

    pyenv activate $ENVIRONMENT >/dev/null 2>&1

    if [[ $? -ne 0 ]]
    then
      echo >/dev/stderr "virtualenv-runner.sh: unable to activate ${ENVIRONMENT}. exiting."
      exit 1
    fi
  fi
fi

pyenv exec @ENTRYPOINT@ $@
exit_code=$?

if [[ -n $RESTORE ]]
then
  pyenv activate $RESTORE >/dev/null 2>&1
fi

exit $exit_code

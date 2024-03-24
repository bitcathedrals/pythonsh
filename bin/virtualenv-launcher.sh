#! /bin/bash

eval "$(pyenv init -)"

if pyenv activate python
then
  echo >/dev/stderr "virtualenv-launcher.sh: unable to activate ${ENVIRONMENT}. exiting."
  exit 1
fi

exec pyenv exec @ENTRYPOINT@ $@


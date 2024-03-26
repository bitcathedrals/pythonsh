#! /bin/bash

TOOLS=$HOME/tools
export PATH="$TOOLS/local/bin:$TOOLS/pipenv/bin:$PATH"

VENV=@VENV@

PYENV_ROOT="$HOME/.pyenv/"
export PATH="$PYENV_ROOT/bin:$PATH"

eval "$(pyenv init -)"

output=$(pyenv activate $VENV 2>&1)

if [[ $? -ne 0 ]]
then
  echo >/dev/stderr "virtualenv-launcher.sh: unable to activate ${VENV} - ${output}. exiting."
  exit 1
fi

exec pyenv exec @ENTRYPOINT@ $@


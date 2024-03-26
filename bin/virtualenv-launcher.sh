#! /bin/bash

TOOLS=$HOME/tools
export PATH="$TOOLS/local/bin:$TOOLS/pipenv/bin:$PATH"

VENV=@VENV@


PATH="$PYENV_ROOT/bin:$PATH"
PATH="$PYENV_ROOT/libexec:$PATH"

export PYENV_ROOT PATH

eval "$(pyenv init -)"

output=$(pyenv activate $VENV 2>&1)

if [[ $? -ne 0 ]]
then
  echo >/dev/stderr "virtualenv-launcher.sh: unable to activate ${VENV} - ${output}. exiting."
  exit 1
fi

exec pyenv exec @ENTRYPOINT@ $@


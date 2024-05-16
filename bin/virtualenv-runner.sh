#! /usr/bin/env bash

VENV=@VENV@

TOOLS=$HOME/tools
PYENV_ROOT="$TOOLS/pyenv"
PATH="$TOOLS/local/bin:$PATH"
PATH="$PYENV_ROOT/bin:$PATH"
PATH="$PYENV_ROOT/libexec:$PATH"

export PYENV_ROOT PATH

eval "$(pyenv init -)"


pyenv activate $VENV

exec pyenv exec @ENTRYPOINT@ $@


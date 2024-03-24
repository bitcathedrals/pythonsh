echo "install-module-tools.sh: activating python"

eval $(pyenv init -)
pyenv activate python

echo "install-module-tools.sh: upgrading pip"
pyenv exec python -m pip upgrade pip

echo "install-module-tools.sh: isntalling pipenv"
pyenv exec python -m pip install pipenv

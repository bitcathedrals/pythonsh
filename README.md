# pythonsh - A python Project Management script

## Goals

pythonsh systematizes the tooling, development, building, release, and deployment of python projects.

It does this with a shell script that performs almost all of the necessary tasks using git-flow, pyenv,
and basic commands. It has some parts that are specific to my project but the great majority of it
can be re-used in any project.

## Installation

The main script is [python.sh](pythonsh/python.sh). I install it as a git submodule
using the script [pysh-install.sh](pythonsh/pysh-install.sh) with the install option.
I then link from the root of the project 

For a new installation into a repository copy pysh-install.sh and run:

```bash
./pysh-install.sh install
```

For cloning when it has already been installed into  the repo use:

```bash
./pysh-install clone
```

### Project Configuration

Then I write a python.sh file like this:

```bash
PYTHON_VERSION="3.10:latest"

VIRTUAL_PREFIX="config"

REGION='us-west-2'
VERSION=0.7.2

AWS_ROLE=<ARN>
AWS_PROFILE=<credentials user>
````

PYTHON_VERSION: version is the version of python for installing via pyenv.

VIRTUAL_PREFIX: the prefix for all the project names such as virtual environment names and package names

REGION: AWS region

VERSION: version of the repo.

Then I write a python.paths file with the source paths to add to python's load path

```bash
src/
src/scripts/
```

## Use

type 
```bash
./py.sh <command>
```

### Tooling

tools-install

install pyenv and git-flow via homebrew

tools-zshrc

install homebrew and pyenv commands into .zshrc

tools-update

update pyenv and git-flow 


### virtual environments

virtual-install

```
install virtual environments <environment>_dev and <environment_release>
```

virtual-destroy

delete virtual environments

virtual-list

list virtual environments


### python commands

test

run tests

paths

install source paths into the current virtual machine environment

python

execute python with remaining arguements passed to the interpreter

run

execute a command in the virtual environment

### AWS commands

aws

run an aws command

### packages

versions

show the versions of everything

update

update packages

 
update-all

full update of pipenv and all packages

list

graph packages

build

build this project as a package, output in dist/

### version control

status

status of repository

fetch

fetch the current branch and main, and develop

pull

pull the current branch

sub-pull

pull submodules

### pythonsh commands

py-status

return the status of the pythonsh module

py-pull

update pythonsh

### release commands

dev-start

create a package lock, copy the lock and the Pipfile to releases.
Make sure that the version was already bumped as this will code the files to the version

dev-finish

push all branches and  tags after a release is finished


### my deploy commands

deploy-m1, deploy-intel

commands to deploy copying package files. These are specific to my configuration
and can be ignored.
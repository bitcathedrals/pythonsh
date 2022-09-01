# pythonsh - A python Project Management Script

## Goals

pythonsh systematizes the tooling, development, building, release, and deployment of python projects.

It does this with a shell script that performs almost all of the necessary tasks using git, git-flow, pyenv, and python build - facilitating sophisticated use of key developer tools.

The commands are all simple with almost all of them being single words with no arguments. pythonsh executes all the tools for you.

## History

pythonsh emerged from years of trying to type out git commands that had no equivalent in graphical tools, and various hacked up shell scripts.

I decided to make a comprehensive script in a single place, and that I would distribute it via github and integrate it with git submodules which made it easy to keep up to date.

It hast vastly accelerated my development speed and systematically almost eliminated errors in project tasks.

## Design

pythonsh is designed as a shell script that is easy to use on MacOS and Linux. The script is integrated into the repository as a submodule making it easy to update and integrate.

It uses single word commands and as much as possible it infers the arguments needed by the tools.

### Tools

pythonsh installs pyenv, pyenv-virtual, and git-flow using homebrew for MacOS.

It sets up virtual environment, wraps package installation and management, executes git commands, executes build commands, and executes release commands.

### Assumptions

pythonsh assumes that you
- initialized the git repo with "git init"
- initialized the git-flow tool with "git flow init"
- Have "build" package in your dev dependencies in Pipfile
- have pyproject.toml if necessary setup correctly, and also the build backend of your choice configured.

## Installation

The main script is [python.sh](pythonsh/python.sh). I install it as a git submodule
using the script [pysh-install.sh](pythonsh/pysh-install.sh).

It has three commands:
- "install" = install as a submodule using ssh for write access
- "public" = install as a submodule with read only access
- "clone" = initialize it when it's already a submodule but there are no files in it.
- "remove" = attempt to completely remove pythonsh

In the root of the project it will install a link for convenience: "py.sh".  

For a new installation into a repository copy pysh-install.sh and run:

```bash
curl https://raw.githubusercontent.com/coderofmattie/pythonsh/main/pythonsh/pysh-install.sh

chmod u+x pysh-install.sh

./pysh-install.sh public
```

It's a simple script so it's easy to verify that the script is safe.

## pythonsh Configuration

### python.sh

In the root of the repository I write a "python.sh" file like this:

```bash
PYTHON_VERSION="3.10:latest"

VIRTUAL_PREFIX="config"

VERSION=0.7.2

AWS_ROLE=<ARN>
AWS_PROFILE=<credentials user>
````

PYTHON_VERSION: (required for python) version is the version of python for installing via pyenv.

VIRTUAL_PREFIX: (required) the prefix for all the project names such as virtual environment names and package names.

VERSION: (required) version of the repo.

AWS_ROLE: (optional): the AWS role used to execute the command
AWS_PROFILE: the credentials (which should also specify region) to use with the role.

### Python Configuration

Then I write a python.paths file with the source paths to add to python's load path:

```bash
src/
```

Each line should be a directory *containing* a module.

Also "pyproject.toml" should be added for python projects so that the "build" module can build a package.

Since "pyproject.toml" can use different backends and has many fields to set I won't cover how to setup "pyproject.toml" here.

### Tooling

- tools-install = install pyenv and git-flow via homebrew
- tools-zshrc   = install homebrew and pyenv commands into .zshrc
- tools-update  = update pyenv and git-flow 

Tooling commands install the necessary tools via homebrew which is a pervasive tool for installing open source software on MacOS.

If you are using Linux you need to install git, git-flow, pyenv, and pyenv-virtualenv

The .zshrc file appends several things to the Zsh login. It adds homebrew, pyenv, and the commands switch_dev, swich_test, and switch_release which switch to the different virtual environments that pythonsh creates.

## Use

The "pysh-install.sh" commands create a link of "py.sh" to the python.sh script so you have a short name to type with the commands.

```bash
./py.sh <command>
```


Almost all of the commands are a single command except for:
- python = execute python in pyenv with the args given
- run = execute any command in pyenv with the args given
- aws = execute awscli with the args given using the AWS_REGION, AWS_ROLE, and AWS_PROFILE as specified in the "python.sh" configuration file.


### virtual environments

- virtual-install  = install virtual environments:
	- <VIRTUAL_PREFIX>_dev for general development
	- <VIRTUAL_PREFIX>_test for testing packages and functionality
	- <VIRTUAL_PREFIX>_release for keeping a release environment
- virtual-destroy  = delete virtual environments
- virtual-list     = list virtual environments

### python commands

- test   = run tests
- paths  = install source paths into the current virtual machine environment
- python = execute python with remaining arguments passed to the interpreter
- run    = execute a command in the virtual environment

### AWS commands

- aws  = run an aws command

### packages

- versions    = show the versions of everything
- update      = update packages
- update-all  = full update of pipenv and all packages
- list        = graph packages
- build       = build this project as a package, output in dist/

### version control

- status   = status of repository
- fetch    = fetch the current branch, main, and develop
- pull     = pull the current branch no fast forward
- sub      = pull submodules
- staged   = show diff of staged files
- history  = show commit history
- merges   = show merges in history
- summary  = show diffstat of the feature branch from develop or from develop to the last tag release
- delta    = show the diff of the feature branch from develop or from develop to the last tag release
- log      = show the log of the feature branch from develop or from develop to the last tag release
- graph    = show a graph history from the feature branch from develop or from develop to 
             the last tag release
- upstream = show a log of the changes from main or develop that haven't been integrated into 
             the current branch
- sync     = merge from the root branch


### release commands

- check   = fetch from main and develop, show logs of any commits from upstream not in the
            develop or main branches. Also check that the working tree is clean.

- start

	1. start an edit of python.sh to bump the version
	2. reload python.sh and commit it
	3. create a lock file and copy the Pipfile and lock file to releases/ with VERSION appended
	4. start a git flow release with VERSION

- release = run git flow release finish with VERSION
- upload  = push main and develop and tags to origin


### my deploy commands

- deploy-m1, deploy-intel

commands to deploy copying package files. These are specific to my configuration
and can be ignored.

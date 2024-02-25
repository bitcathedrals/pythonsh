# pythonsh - A python Project Management Script

## Goals

pythonsh systematizes the tooling, development, building, release, and
deployment of python projects.

It does this with a shell script that performs almost all of the
necessary tasks using git, git-flow, pyenv, and python build -
facilitating sophisticated use of key developer tools.

The commands are all simple with almost all of them being single words
with no arguments. pythonsh executes all the tools for you.

## History

pythonsh emerged from years of trying to type out git commands that
had no equivalent in graphical tools, and various hacked up shell
scripts.

I decided to make a comprehensive script in a single place, and that I
would distribute it via github and integrate it with git submodules
which made it easy to keep up to date.

It hast vastly accelerated my development speed and systematically
almost eliminated errors in project tasks.

## Design

pythonsh is designed as a shell script that is easy to use on MacOS
and Linux. The script is integrated into the repository as a submodule
making it easy to update and integrate.

It uses single word commands and as much as possible it infers the
arguments needed by the tools.

### Tools

pythonsh installs pyenv, pyenv-virtual, and git-flow using homebrew
for MacOS.

It sets up virtual environment, wraps package installation and
management, executes git commands, executes build commands, and
executes release commands.

### Assumptions

pythonsh assumes that you
- initialized the git repo with "git init"
- initialized the git-flow tool with "git flow init"
- have pyproject.toml if necessary setup correctly, and also the build backend of your choice configured.

## Installation

The main script is [python.sh](pythonsh/python.sh). 

I install it as a git submodule using the script
[pysh-install.sh](pythonsh/pysh-install.sh).

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
# pythonsh configuration file
VERSION=0.9.8

PACKAGES=pythonsh
SOURCE=pyutils

BUILD_NAME=pythonsh

VIRTUAL_PREFIX='pythonsh'


PYTHON_VERSION='3.12'
````

VERSION: the version of the sofware

VIRTUAL_PREFIX: (required) the prefix for all the project names such
as virtual environment names and package names.

SOURCE: the source tree

BUILD_NAME: the name of the package built

PYTHON_VERSION: what version of python to use

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

tools-install, tools-zshrc, tools-prompt all use git to install pyenv,
pyenv-virtual, zshrc file, and zsh prompt extensions.

if you need to update tools, you can call tools-install again.

The .zshrc file appends several things to the Zsh login. It adds the
commands switch_dev, swich_test, and switch_release which switch to
the different virtual environments that pythonsh creates.

switch_global <name> switches to a non-project specific virtualenv

## Use

The "pysh-install.sh" commands create a link of "py.sh" to the
python.sh script so you have a short name to type with the commands.

```bash
./py.sh <command>
```


# python.sh

## [tools commands]

tools-macos   = install pyenv and pyenv virtual from brew on MacOS
tools-unix    = install pyen and pyenv virtual from source on UNIX (call again to update)

tools-update-macos  = update tools from homebrew

tools-zshrc         = install hombrew, pyenv, and pyenv switching commands into .zshrc
tools-prompt        = install prompt support with pyeenv, git, and project in the prompt

tools-update-macos  = update the pyenv tools and update pip/pipenv in the current virtual machine

[virtual commands]

project-virtual  = create: dev, test, and release virtual environments from settings in python.sh
global-virtual   = (VERSION, NAME): create NAME virtual environment

project-destroy  = delete all the project virtual environments
global-destroy   = delete a global virtual environment

virtual-list     = list virtual environments

## [initialization]

minimal          = pythonsh only bootstrap for projects with only built-in deps
bootstrap        = two stage bootstrap of minimal, pipfile generate, install source deps, pipfile, install pkg deps
pipfile          = generate a pipfile from all of the packages in the source tree + pythonsh + site-packages deps

## [using virtual and source paths]

switch_dev       = switch to dev virtual environment
switch_test      = switch to test virtual environment
switch_release   = switch to release virtual environment

show-paths = list .pth source paths
add-paths  = install .pth source paths into the python environment
rm-paths   = remove .pth source paths

## [python commands]

test    = run pytests
python  = execute python in pyenv
repl    = execute ptpython in pyenv
run     = run a command in pyenv

## [aws commands]

aws       = execute a aws cli command

## [package commands]

versions   = display the versions of python and installed packages
locked     = update from lockfile
all        = update pip and pipenv install dependencies and dev, lock and check
update     = update installed packages, lock and check
remove     = uninstall the listed packages
list       = list installed packages

build      = build packages

## [submodule]
modinit             = initialize and pull all submodules
modadd <1> <2> <3>  = add a submodule where 1=repo 2=branch 3=localDir (commit after)
modupdate <module>  = pull the latest version of the module
modrm  <submodule>  = delete a submodule
modall              = update all submodules

## [version control]

verify     = show log with signatures for verification
status     = git state, submodule state, diffstat for changes in tree
fetch      = fetch main, develop, and current branch
pull       = pull current branch no ff
sub        = update submodules
init       = init any bare submodules
staged     = show staged changes
merges     = show merges only
history    = show commit history
summary    = show diffstat of summary between feature and develop or last release and develop
delta      = show diff between feature and develop or last release and develop
log        = show log between feature and develop or last release and develop
graph      = show history between feature and develop or last release and develop
upstream   = show upstream changes that havent been merged yet
sync       = merge from the root branch commits not in this branch no ff

## [release]

check      = fetch main, develop from origin and show log of any pending changes
start      = initiate an EDITOR session to update VERSION in python.sh, reload config,
             snapshot Pipfile if present, and start a git flow release with VERSION

             for the first time pass version as an argument: "./py.sh start 1.0.0"

             if you encounter a problem you can fix it and resume with ./py.sh start resume [merge|pipfile]
             to resume at that point in the flow.
release    = execute git flow release finish with VERSION
upload     = push main and develop branches and tags to remote

[misc]
purge      = remove all the __pycache__ dirs

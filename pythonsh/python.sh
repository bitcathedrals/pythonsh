#! /usr/bin/env bash

test -f python.sh && source python.sh

function add_src {
    site=`pyenv exec python -c 'import site; print(site.getsitepackages()[0])'`

    echo "include_src: setting dev.pth in $site/dev.pth"

    test -d $site || mkdir -p $site

    cat python.paths | tr -s '\n' | sed -e "s,^,$PWD/," >"$site/dev.pth"
}

function remove_src {
    site=`pyenv exec python -c 'import site; print(site.getsitepackages()[0])'`

    echo "remove_src: removing dev.pth from $site/dev.pth"

    test -f "$site/dev.pth" && rm "$site/dev.pth"
}

function root_to_branch {
    branch=$(git branch | grep '*' | cut -d ' ' -f 2)

    if [[ $branch == "develop" ]]
    then
        if [[ $1 == "norelease" ]]
        then
            root="main"
        else
            root=$(git tag | tail -n 1)
        fi
    else
        root='develop'
    fi
}

function setup_pyenv {
  test -z $PYENV_ROOT || export PYENV_ROOT="$HOME/.pyenv"
  command -v pyenv >/dev/null || export PATH="$PATH:$PYENV_ROOT/bin"

  eval "$(pyenv init -)"

  if [[ $? -gt 0 ]]
  then
    echo "could not execute pyenv init --shell. FAILED!"
    return 1
  fi

  return 0
}

function deactivate_if_needed {
  ver=$(pyenv version)

  echo "$ver" | cut -d ' ' -f 1 | grep -v 'system'

  if [[ $? -gt 0 ]]
  then
    return 0
  fi

  if ! pyenv deactivate
  then
    echo "deactive of $ver failed!"
    return 1
  fi

  return 0
}

function latest_virtualenv_python {
  VERSION=$1
  escaped=$(echo "${VERSION}" | sed -e 's/\./\\\./g')

  LATEST_PYTHON=`pyenv versions | grep -E "^ *${escaped}\\\.[0-9]+\$" | sed -e "s,^ *,,"`
  export LATEST_PYTHON

  echo "Using Python version ${LATEST_PYTHON}"

  return 0
}

function install_virtualenv_python {
  setup_pyenv

  deactivate_if_needed || return 1

  VERSION=$1

  echo -n "Updating Python interpreter: ${VERSION}..."

  if ! pyenv install -v --skip-existing $VERSION
  then
    echo "FAILED!"
    return 1
  fi

  latest_virtualenv_python $VERSION

  return 0
}

function install_virtualenv {
  LATEST=$1
  NAME=$2

  if ! pyenv virtualenv "$LATEST" "$NAME"
  then
    echo "FAILED!"
    return 1
  fi

  echo "done."
  return 0
}

function install_project_virtualenv {
  VERSION=$1

  ENV_ONE=$2
  ENV_TWO=$3
  ENV_THREE=$4

  install_virtualenv_python $VERSION || return 1

  echo -n "creating project virtual environments: "

  if [[ -n $ENV_ONE ]]
  then
    install_virtualenv $LATEST_PYTHON $ENV_ONE || return 1
  fi

  echo -n ",$ENV_ONE"

  if [[ -n $ENV_TWO ]]
  then
    install_virtualenv $LATEST_PYTHON $ENV_TWO || return 1
  fi

  echo -n ",$ENV_TWO"

  if [[ -n $ENV_THREE ]]
  then
    install_virtualenv $LATEST_PYTHON $ENV_THREE || return 1
  fi

  echo ",${ENV_THREE}...done!"
  return 0
}

case $1 in

#
# tooling
#
    "tools-macos")
        echo "installing brew tools"

        brew update

        brew install pyenv
        brew install pyenv-virtualenv
        brew install git-flow
    ;;
    "tools-unix")
      echo "installing python environment tools for UNIX"

      PYENV_ROOT="$HOME/.pyenv"
      TOOLS="$HOME/tools"

      test -d $TOOLS || mkdir $TOOLS
      test -d "$TOOLS/local" || mkdir "$TOOLS/local"

      if test -d $PYENV_ROOT && test -d $PYENV_ROOT/.git
      then
        echo "updating $PYENV_ROOT"
        (cd $PYENV_ROOT && git pull)
      else
        echo "cloning pyenv into $PYENV_ROOT"
        git clone https://github.com/pyenv/pyenv.git $PYENV_ROOT
      fi

      VIRTUAL="$TOOLS/pyenv-virtual"

      if test -d $VIRTUAL && test -d "$VIRTUAL/.git"
      then
        echo "updating pyenv virtual"
        (cd $VIRTUAL && git pull)
      else
        echo "cloning pyenv virtual into $VIRTUAL"
        (git clone https://github.com/pyenv/pyenv-virtualenv.git $VIRTUAL)
      fi

      (cd $VIRTUAL && export PREFIX="$TOOLS/local" && ./install.sh)

      echo "export PATH=\"\$PATH:${PYENV_ROOT}/bin:${TOOLS}/local/bin\"" >>~/.zshrc.custom

      echo "installation completed"
    ;;
    "tools-zshrc")
       echo "adding shell code to .zshrc, you may need to edit the file."

        cat >>~/.zshrc <<SHELL
DEFAULT_PYPENV="\$HOME/.pyenv/"

test -f \$HOME/.zshrc.custom && source \$HOME/.zshrc.custom

if [[ -f \$HOME/homebrew/bin/brew ]]
then
    eval "\$(\$HOME/homebrew/bin/brew shellenv)"
else
   which brew >/dev/null 2>&1 && eval "\$(brew shellenv)"
fi

if ! command -v pyenv >/dev/null 2>&1
then
  test -z "\${PYENV_ROOT}" || export PYENV_ROOT="\$DEFAULT_PYENV"
  export PATH="\$PATH:\$PYENV_ROOT/bin"
fi

eval "\$(pyenv init -)"

test -f \$HOME/.zshrc.prompt && source \$HOME/.zshrc.prompt

function deactivate_if_needed {
  ver=\$(pyenv version)

  echo "\$ver" | cut -d ' ' -f 1 | grep -v 'system' || return 0

  if ! pyenv deactivate
  then
    echo "deactive of \$ver failed!"
    return 1
  fi

  return 0
}

function load_python_sh {
  if test -f python.sh
  then
    source python.sh
  else
    echo "can\'t find python.sh - are you in the project root?"
    return 1
  fi

  return 0
}

function switch_to_virtual {
  environment=\$1

  type=\$(echo "\$1" | cut -d ':' -f 1)
  name=\$(echo "\$1" | cut -d ':' -f 2)

  if [[ \$type == "project" ]]
  then
    load_python_sh || return 1
    virt="\${VIRTUAL_PREFIX}_\${name}"
  else
    virt="\${name}"
  fi

  deactivate_if_needed || return 1

  echo -n ">>>switching to: \${virt}..."

  if pyenv activate "\${virt}"
  then
    echo "completed."
  else
    echo "FAILED!"
    return 1
  fi

  return 0
}

function switch_dev {
  if switch_to_virtual "project:dev" || return 1
  return 0
}

function switch_test {
  if switch_to_virtual "project:test" || return 1
  return 0
}

function switch_release {
  if switch_to_virtual "project:release" || return 1
  return 0
}

function switch_global {
  if [[ -z \$1 ]]
  then
    echo "you need to specify a virtual environment to switch to as the sole argument"
    return 1
  fi

  switch_to_virtual "global:\${1}" || return 1

  return 0
}
SHELL
    ;;
    "tools-prompt")
        echo "installing standard prompt with pyenv and github support"
        cp pythonsh/prompt.sh $HOME/.zshrc.prompt
    ;;
    "tools-update-macos")
        brew update

        brew upgrade pyenv
        brew upgrade pyenv-virtualenv
        brew upgrade git-flow
    ;;
#
# virtual environments
#
    "project-virtual")
        setup_pyenv

        install_project_virtualenv $PYTHON_VERSION "${VIRTUAL_PREFIX}_dev" "${VIRTUAL_PREFIX}_test" "${VIRTUAL_PREFIX}_release" || exit 1

        echo "you need to run switch_dev, switch_test, or switch_release to activate the new environments."
    ;;
    "global-virtual")
        shift

        VERSION="$1"
        NAME="$2"

        setup_pyenv

        install_virtualenv_python $VERSION || exit 1

        echo -n "creating global virtual environment: ${NAME} from ${LATEST_PYTHON}"

        install_virtualenv $LATEST_PYTHON $NAME || exit 1

        echo "you need to run \"switch_global $NAME\" to activate the new environment."
    ;;
    "project-destroy")
        pyenv virtualenv-delete "${VIRTUAL_PREFIX}_dev"
        pyenv virtualenv-delete "${VIRTUAL_PREFIX}_test"
        pyenv virtualenv-delete "${VIRTUAL_PREFIX}_release"
    ;;
    "global-destroy")
      shift
      NAME=$1

      if ! pyenv virtualenv-delete $NAME
      then
        echo "delete of global virtualenv $NAME FAILED!"
        exit 1
      fi

      exit 0
    ;;
    "virtual-list")
        pyenv virtualenvs
    ;;

#
# initialization commands
#
    "bootstrap")
       pyenv exec python -m pip install pipenv
       pyenv exec python -m pip install --upgrade pip

       test -f Pipfile.lock || touch Pipfile.lock
       export PIPENV_PIPFILE='pythonsh/Pipfile'; pipenv install

       test -f pythonsh/Pipfile.lock && rm pythonsh/Pipfile.lock
    ;;
    "pipfile")
      pipdirs="pythonsh"

      for dep_dir in $(find src -type d -depth 1 -print)
      do
        echo >/dev/stderr "checking dependency: $dep_dir"

        repos=`echo ${dep_dir}/*.pypi`

        if [[ -f "${dep_dir}/Pipfile" || -n $repos ]]
        then
          pipdirs="${pipdirs} ${dep_dir}"
        fi
      done

      eval "pyenv exec python pythonsh/pyutils/catpip.py $pipdirs"
    ;;

#
# python commands
#

    "test")
        shift
        pyenv exec python -m pytest tests $@
    ;;
    "show-paths")
        shift
        pyenv exec python -c "import sys; print(sys.path)"
    ;;
    "add-paths")
        shift
        add_src
        pyenv exec python -c "import sys; print(sys.path)"
    ;;
    "rm-paths")
        shift
        remove_src
        pyenv exec python -c "import sys; print(sys.path)"
    ;;
    "python")
        shift
        if [[ -f  env.variables ]]
        then
          source env.variables
        fi

        exec pyenv exec python $@
    ;;
    "repl")
        shift

        if [[ -f env.variables ]]
        then
          source env.variables
        fi

        exec pyenv exec ptpython $@
    ;;
    "run")
        shift

        if [[ -f env.variables ]]
        then
          source env.variables
        fi

        exec pyenv exec $@
    ;;

 #
 # AWS commands
 #

    "aws-creds")
      shift

      AWS_ROLE=$1

      test -f aws.sh && source aws.sh

      printf >${AWS_ROLE}.sh "export AWS_ACCESS_KEY_ID=\"%s\" AWS_SECRET_ACCESS_KEY=\"%s\" AWS_SESSION_TOKEN=\"%s\"" \
                  $(aws sts assume-role \
                    --role-arn $AWS_ROLE \
                    --role-session-name pythonsh-cli-creds \
                    --profile $PROFILE \
                    --query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" \
                    --output text)
    ;;
    "aws")
        shift

        test -f aws.sh && source aws.sh

        role=""

        if [[ -n $1 ]]
        then
          if echo "$1" | grep -E '^role='
          then
            role=$(echo $1 | cut -d '=' -f 2)

            if [[ -f ${role}.sh ]]
            then
              source ${role}.sh
              shift
            else
              echo "role file: ${role}.sh cound not be found"
              exit 1
            fi
          fi
        fi

        aws $@ --profile $PROFILE --output json
    ;;

#
# packages
#
    "versions")
        pyenv version
        pyenv exec python --version
        pipenv graph
    ;;
    "locked")
      pipenv sync
    ;;
    "update")
        pipenv install --skip-lock
        pyenv rehash
        pipenv lock

        pipenv check
    ;;
    "update-all")
        test -f Pipfile.lock || touch Pipfile.lock

        pyenv exec python -m pip install --upgrade pip

        pipenv install --dev

        pyenv rehash
        pipenv lock

        # check for known security vulnerabilities
        pipenv check
    ;;
    "list")
        pipenv graph
    ;;
    "build")
        pyenv exec python -m build

        find . -name '*.egg-info' -type d -print | xargs rm -r
        find . -name '__pycache__' -type d -print | xargs rm -r

        test -f Pipfile.lock && rm Pipfile.lock
    ;;

#
# modules
#
    "modinit")
      git submodule init
      git submodule update
    ;;
    "modadd")
      shift

      if [[ -z "$1" || -z "$2" || -z "$3" ]]
      then
        echo "pythonsh: add submodule command requires <repo> <branch> <local>"
        exit 1
      fi

      if git submodule add -b $2 $1 $3
      then
        echo "pythonsh: add ok. please remember to commit"
      else
        echo "pythonsh: add failed. cleanup required."
      fi
    ;;
    "modupdate")
      shift

      if [[ -z $1 ]]
      then
        echo "pythonsh: update a submodule requires a submodule path"
        exit 1
      fi

      if (cd $1 && git pull --no-ff)
      then
        echo "pythonsh: update ok. please remember to test and commit."
      else
        echo "pythonsh: update failed. cleanup required."
      fi
    ;;
    "modbranch")
      shift

      if [[ -z $1 || -z $2 ]]
      then
        echo "pythonsh: update a submodule requires a submodule path and a branch"
        exit 1
      fi

      if (cd $1 && git checkout $2)
      then
        echo "pythonsh: switch to branch $2 ok. please remember to commit."
      else
        echo "pythonsh: switch submodule $1 to branch $2 failed. cleanup required."
      fi
    ;;
    "modrm")
      shift

      if git rm $1 && git rm --cached $1 && rm -rf $1 && rm -rf .git/modules/$1
      then
        echo "pythonsh: removal of $1 succeeded."
      else
        echo "pythonsh: removal of $1 failed. Repo is in a unknown state"
      fi
    ;;
    "modall")
       git submodule foreach 'git pull --no-ff'
    ;;
#
# version control
#
    "status")
        git status
        git submodule foreach 'git status'
        git diff --stat
    ;;
    "fetch")
        git fetch
        git fetch origin main
        git fetch origin develop
    ;;
    "pull")
        git pull --no-ff
    ;;
    "sub")
        git submodule update --remote
    ;;
    "init")
        git submodule update --init --recursive
    ;;
    "staged")
        git diff --cached
    ;;
    "summary")
        root_to_branch

        echo ">>>showing summary between $root and $branch"
        git diff "${root}..${branch}" --stat
    ;;
    "delta")
        root_to_branch

        echo ">>>showing delta between $root and $branch"
        git diff "${root}..${branch}"
    ;;
    "merges")
        git log --merges --oneline
    ;;
    "history")
        echo ">>>showing history"
        git log --oneline
    ;;
    "log")
        root_to_branch

        echo ">>>showing log between $root and $branch"
        git log "${root}..${branch}" --oneline
    ;;
    "graph")
        root_to_branch

        echo ">>>showing history between $root and $branch"
        git log "${root}..${branch}" --oneline --graph --decorate --all
    ;;
    "upstream")
        root_to_branch norelease

        git fetch origin main
        git fetch origin develop

        echo ">>>showing upstream changes from: ${root}->${branch}"
        git log --no-merges ${root} ^${branch} --oneline
    ;;
    "sync")
        root_to_branch norelease

        echo ">>>syncing from: ${root}->${branch}"

        git merge --no-ff --stat ${root}
    ;;

#
# release environment
#
    "check")
        echo "===> remember to pull deps with update if warranted <==="

        echo "===> fetching new commits from remote <==="
        git fetch origin main
        git fetch origin develop

        echo "===> showing unmerged differences <===="

        git log main..origin/main --oneline
        git log develop..origin/develop --oneline

        echo "===> checking if working tree is dirty <==="

        if git diff --quiet
        then
            echo "working tree clean - proceed!"
        else
            echo "working tree dirty - DO NOT RELEASE"

            git status
            exit 1
        fi
    ;;
    "start")
        if git diff --quiet
        then
            echo ">>>working tree clean - proceeding with release: $VERSION"
        else
            echo "working tree dirty - terminating release:"

            git status
            exit 1
        fi

        echo -n ">>>please edit python.sh with an updated version in 3 seconds."
        sleep 1
        echo -n "."
        sleep 1
        echo -n "."
        sleep 1

        $EDITOR python.sh || exit 1
        source python.sh

        if [[ -f pyproject.toml ]]
        then
            echo -n ">>>please edit pyproject.toml with an updated version in 3 seconds."
            sleep 1
            echo -n "."
            sleep 1
            echo "."
            sleep 1

            $EDITOR pyproject.toml || exit 1
        fi

        test -d releases || mkdir releases
        test -f Pipfile && pipenv lock

        VER_PIP="releases/Pipfile-$VERSION"
        VER_LOCK="releases/Pipfile.lock-$VERSION"

        test -f Pipfile.lock && cp Pipfile.lock $VER_LOCK
        test -f Pipfile && cp Pipfile $VER_PIP

        git add python.sh

        test -f pyproject.toml && git add pyproject.toml

        test -f $VER_PIP && git add $VER_PIP
        test -f $VER_LOCK && git add $VER_LOCK

        echo ">>>commiting bump to to $VERSION"

        git commit -m "bump to version $VERSION"

        echo -n "initiating git flow release start with version: $VERSION in 3 seconds."
        sleep 1
        echo -n "."
        sleep 1
        echo "."
        sleep 1

        git flow release start $VERSION
    ;;
    "release")
        git flow release finish $VERSION || exit 1
    ;;
    "upload")
        git push origin main:main
        git push origin develop:develop

        git push --tags
    ;;
    "help"|""|*)
        cat <<HELP
python.sh

[tools commands]

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

[initialization]

bootstrap        = do a pip install of deps for pythonsh python utilities
pipfile          = generate a pipfile from all of the packages in the source tree + pythonsh

[using virtual and source paths]

switch_dev       = switch to dev virtual environment
switch_test      = switch to test virtual environment
switch_release   = switch to release virtual environment

show-paths = list .pth source paths
add-paths  = install .pth source paths into the python environment
rm-paths   = remove .pth source paths

[python commands]

test    = run pytests
python  = execute python in pyenv
repl    = execute ptpython in pyenv
run     = run a command in pyenv

[aws commands]

aws       = execute a aws cli command

[package commands]

versions   = display the versions of python and installed packages
locked     = update from lockfile
update     = update installed packages
update-all = update pip and installed
list       = list installed packages

build      = build packages

[submodule]
modinit             = initialize and pull all submodules
modadd <1> <2> <3>  = add a submodule where 1=repo 2=branch 3=localDir (commit after)
modupdate <module>  = pull the latest version of the module
modrm  <submodule>  = delete a submodule
modall              = update all submodules

[version control]

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

[release]

check      = fetch main, develop from origin and show log of any pending changes
start      = initiate an EDITOR session to update VERSION in python.sh, reload config,
             snapshot Pipfile if present, and start a git flow release with VERSION
release    = execute git flow release finish with VERSION
upload     = push main and develop branches and tags to remote
HELP
    ;;
esac

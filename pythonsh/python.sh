#! /usr/bin/env bash

test -f python.sh && source python.sh

export PIPENV_VERBOSITY=-1

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

  echo "creating project virtual environments"

  if [[ -n $ENV_ONE ]]
  then
    echo -n "pythonsh - building: ${ENV_ONE}...."
    install_virtualenv $LATEST_PYTHON $ENV_ONE || return 1
  fi

  if [[ -n $ENV_TWO ]]
  then
    echo -n "pythonsh - building: ${ENV_TWO}...."
    install_virtualenv $LATEST_PYTHON $ENV_TWO || return 1
  fi

  if [[ -n $ENV_THREE ]]
  then
    echo -n "pythonsh - building: ${ENV_THREE}..."
    install_virtualenv $LATEST_PYTHON $ENV_THREE || return 1
  fi

  return 0
}

function find_deps {
  pipdirs="pythonsh"

  for dep_dir in $(find ${SOURCE} -type d -depth 1 -print 2>/dev/null)
  do
    repos=`ls 2>/dev/null ${dep_dir}/*.pypi  | sed -e s,\s*,,g`

    if [[ -f "${dep_dir}/Pipfile" || -n $repos ]]
    then
      pipdirs="${pipdirs} ${dep_dir}"
    fi
  done

  site_dir=$(pyenv exec python -m site | grep 'site-packages' | grep -v USER_SITE | sed -e 's,^ *,,' | sed -e s/,//g | sed -e s/\'//g)

  echo >/dev/stderr "pipfile: using site dir: \"${site_dir}\""

  for dep_dir in $(find "${site_dir}" -type d -depth 1 -print 2>/dev/null)
  do
    if [[ ! `basename $dep_dir` == 'examples' ]]
    then
      repos=`ls 2>/dev/null ${dep_dir}/*.pypi | sed -e s,\s*,,g`

      if [[ -f "${dep_dir}/Pipfile" || -n $repos ]]
      then
        pipdirs="${pipdirs} ${dep_dir}"
      fi
    fi
  done

  echo >/dev/stderr "pipfile: procesing dirs: $pipdirs"
}

function find_catpip {
  catpip="pythonsh/pyutils/catpip.py pipfile"

  if command -v catpip >/dev/null 2>&1
  then
    echo >/dev/stderr "pipfile: using installed catpip: catpip"
    catpip="catpip"
  elif [[ -f pythonsh/pyutils/catpip.py ]]
  then
    echo >/dev/stderr "pipfile: using distributed catpip: pythonsh/pyutils/catpip.py"
    catpip="pythonsh/pyutils/catpip.py"
  elif [[ -f pyutils/catpip.py ]]
  then
    echo >/dev/stderr "pipfile: using internal catpip: pyutils/catpip.py"
    catpip="pyutils/catpip.py"
   else
     echo >/dev/stderr "pipfile: can\'t find catpip.py... exiting with error."
     exit 1
   fi
}


case $1 in
  "version")
    echo "pythonsh version is: 0.9.9"
  ;;

#
# tooling
#
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
if [[ -f \$HOME/homebrew/bin/brew ]]
then
    eval "\$(\$HOME/homebrew/bin/brew shellenv)"
else
   which brew >/dev/null 2>&1 && eval "\$(brew shellenv)"
fi

test -f \$HOME/.zshrc.custom && source \$HOME/.zshrc.custom

DEFAULT_PYPENV="\$HOME/.pyenv/"

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

        if [[ -n "$VERSION" ]]
        then
          echo "global-virtual: VERSION (first argument) is missing."
          exit 1
        fi

        if [[ -n "$NAME" ]]
        then
          echo "global-virtual NAME (second argument) is missing."
          exit 1
        fi

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
    "minimal")
       test -f Pipfile.lock || touch Pipfile.lock

       test -e pytest.ini || ln -s pythonsh/pytest.ini

       pyenv exec python -m pip install --upgrade pip
       pyenv exec python -m pip install pipenv

       pipfile="pythonsh/Pipfile"

       if [[ -f $pipfile ]]
       then
         echo "using distributed Pipfile for minimal bootstrap"
       elif [[ -f Pipfile ]]
       then
          echo "using base Pipfile for minimal... this is for pythonsh internal use only"
          pipfile="Pipfile"
       else
         echo "No Pipfile could be found, exiting"
         exit 1
       fi

       export PIPENV_PIPFILE="$pipfile"; pipenv install
    ;;
    "bootstrap")
      $0 minimal || exit 1

      # generate the initial pipfile getting deps out of the source tree
      $0 pipfile >Pipfile || exit 1

      # do the basic install
      $0 all || exit 1

      # get all the pipfiles even in site-dir from installed packages
      $0 pipfile >Pipfile || exit 1

      $0 update || exit 1

      echo "bootstrap complete"
    ;;
    "pipfile")
      find_deps
      find_catpip

      eval "pyenv exec python $catpip pipfile $pipdirs"
    ;;
    "project")
      find_deps
      find_catpip

      eval "pyenv exec python $catpip project $pipdirs"
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
    "all")
      test -f Pipfile.lock || touch Pipfile.lock

      pyenv exec python -m pip install --upgrade pip
      pyenv exec python -m pip install --upgrade pipenv

      pipenv install --dev

      pyenv rehash
      pipenv lock

      # check for known security vulnerabilities
      pipenv check
    ;;
    "update")
        pipenv update --skip-lock
        pyenv rehash
        pipenv lock

        pipenv check
    ;;
    "remove")
      shift
      pipenv uninstall $@
    ;;
    "list")
        pipenv graph
    ;;
    "build")
      $0 project >pyproject.toml

      pyenv exec python -m build

      find . -name '*.egg-info' -type d -print | xargs rm -r
      find . -name '__pycache__' -type d -print | xargs rm -r
    ;;

#
# modules
#
    "modinit")
      git submodule init
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

      if (cd $1 && git pull)
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

      if git rm $1 && git rm --cached $1
      then
        if [[ -d $1 ]]
        then
          rm -rf $1
          echo "manual cleanup of source tree $1 done."
        fi

        if [[ -d ".git/modules/$1" ]]
        then
          rm -rf ".git/modules/$1"
          echo "manual cleanup of git module $1 done."
        fi

        echo "pythonsh: removal of $1 succeeded."
      else
        echo "pythonsh: removal of $1 failed. Repo is in a unknown state"
      fi
    ;;
    "modall")
      echo "all submodule updating..."
      git submodule update --init --recursive || exit 1
      echo "all submodule update done."
    ;;
#
# version control
#
    "track")
      shift
      git branch -u $1/$2
    ;;
    "info")
      git branch -vv
    ;;
    "verify")
      exec git log --show-signature $@
    ;;
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
      shift

      VERSION="$1"
      resume=""

      if pyenv exec python --version >/dev/null 2>&1
      then
        echo ">>> pyenv python found."
      else
        echo ">>> pyenv python NOT FOUND! exiting now!"
        exit 1
      fi

      if [[ $VERSION == "resume" ]]
      then
        resume=$2
        echo "attempting to resume at point: $resume"

        if [[ $resume == "merge" || $resume == "pipfile" || $resume == "commit" ]]
        then
          source "python.sh"
        else
          echo "resume must be either: \"merge\" or \"pipfile\" or \"commit\" ... doing the version bumps is the beginning and start takes a VERSION as an argument to start"
          exit 1
        fi
      else
        if git diff --quiet
        then
          echo ">>>working tree clean - proceeding with release: $VERSION"
        else
          echo "working tree dirty - terminating release:"

          git status
          exit 1
        fi
      fi

      if [[ -z $resume ]]
      then
        echo -n "initiating git flow release start with version: $VERSION in 3 seconds."
        sleep 1
        echo -n "."
        sleep 1
        echo "."
        sleep 1

        git flow release start $VERSION

        if [[ $? -ne 0 ]]
        then
          echo "git flow release start $VERSION FAILED!"
          exit 1
        fi

        echo -n ">>>please edit python.sh with an updated version in 3 seconds."
        sleep 1
        echo -n "."
        sleep 1
        echo -n "."
        sleep 1

        $EDITOR python.sh || exit 1
        git add python.sh

        echo ">>>re-loading python.sh"
        source python.sh

        if [[ -f Pipfile ]]
        then
          echo -n ">>>regenerating pyproject.toml."

          $0 project
          git add pyproject.toml
        fi
      fi

      if [[ -z $resume || $resume == "merge" ]]
      then
        echo -n ">>>merging work from develop in 3 seconds: "
        sleep 1
        echo -n "."
        sleep 1
        echo -n "."
        sleep 1
        echo "."

        if git merge --no-ff develop
        then
          echo "merge ok!"
        else
          echo "error result from merge, probably a conflict, please clean up manually and restart with ./py.sh start resume pipfile"
        fi
      fi

      if [[ -z $resume ||  $resume == "merge" || $resume == "pipfile" ]]
      then
        if [[ -f Pipfile ]]
        then
          test -d releases || mkdir releases
          test -f Pipfile && pipenv lock

          git add Pipfile.lock

          VER_PIP="releases/Pipfile-$VERSION"
          VER_LOCK="releases/Pipfile.lock-$VERSION"

          test -f Pipfile.lock && cp Pipfile.lock $VER_LOCK
          test -f Pipfile && cp Pipfile $VER_PIP

          test -f $VER_PIP && git add $VER_PIP
          test -f $VER_LOCK && git add $VER_LOCK
        fi
      fi

      if [[ -z $resume || $resume == "merge" || $resume == "pipfile" || $resume == "commit" ]]
      then
        echo ">>>commiting bump to to $VERSION"

        git commit -m "(release) release version: $VERSION"
      fi

      echo "ready for release finish: please finish with ./py.sh release once you are ready"
    ;;
    "release")
        git flow release finish $VERSION || exit 1
    ;;
    "upload")
        git push origin main:main
        git push origin develop:develop

        git push --tags
    ;;
    "purge")
      for cache in $(find . -name '__pycache__' -type d -print)
      do
        echo "purging: $cache"
        rm -r $cache
      done
    ;;
    "help"|""|*)
        cat <<HELP
python.sh

[tools commands]

tools-unix    = install pyen and pyenv virtual from source on UNIX (call again to update)

tools-zshrc         = install hombrew, pyenv, and pyenv switching commands into .zshrc
tools-prompt        = install prompt support with pyeenv, git, and project in the prompt

[virtual commands]

project-virtual  = create: dev, test, and release virtual environments from settings in python.sh
global-virtual   = (VERSION, NAME): create NAME virtual environment

project-destroy  = delete all the project virtual environments
global-destroy   = delete a global virtual environment

virtual-list     = list virtual environments

[initialization]

minimal          = pythonsh only bootstrap for projects with only built-in deps
bootstrap        = two stage bootstrap of minimal, pipfile generate, install source deps, pipfile, install pkg deps
pipfile          = generate a pipfile from all of the packages in the source tree + pythonsh + site-packages deps
project          = generate a pyproject.toml file

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

[package commands]

versions   = display the versions of python and installed packages
locked     = update from lockfile
all        = update pip and pipenv install dependencies and dev, lock and check
update     = update installed packages, lock and check
remove     = uninstall the listed packages
list       = list installed packages

build      = build packages

[submodule]
modinit             = initialize and pull all submodules
modadd <1> <2> <3>  = add a submodule where 1=repo 2=branch 3=localDir (commit after)
modupdate <module>  = pull the latest version of the module
modrm  <submodule>  = delete a submodule
modall              = update all submodules

[version control]
track <1> <2>  = set upstream tracking 1=remote 2=branch
info       = show branches, tracking, and status
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

[release]

check      = fetch main, develop from origin and show log of any pending changes
start      = initiate an EDITOR session to update VERSION in python.sh, reload config,
             snapshot Pipfile if present, and start a git flow release with VERSION

             for the first time pass version as an argument: "./py.sh start 1.0.0"

             if you encounter a problem you can fix it and resume with ./py.sh start resume [merge|pipfile|commit]
             to resume at that point in the flow.
release    = execute git flow release finish with VERSION
upload     = push main and develop branches and tags to remote

[misc]
purge      = remove all the __pycache__ dirs
HELP
    ;;
esac

exit 0

#! /usr/bin/env bash

if [[ ! -f python.sh ]]
then
  echo "python.sh not found! exiting"
  exit 1
fi

source python.sh

if [[ -z "$VIRTUAL_PREFIX" ]]
then
  echo "python.sh: VIRTUAL_PREFIX not set"
  exit 1
fi

if [[ -z "$PYTHON_VERSION" ]]
then
  echo "python.sh: PYTHON_VERSION not set"
  exit 1
fi

export PIPENV_VERBOSITY=-1

function add_src {
  site=`pyenv exec python -c 'import site; print(site.getsitepackages()[0])'`

  echo "include_src: setting dev.pth in $site/dev.pth"

  test -d $site || mkdir -p $site

  cat python.paths | grep -E '^/' >"$site/dev.pth"
  cat python.paths | grep -v -E '^/' | tr -s '\n' | sed -e "s,^,$PWD/," >>"$site/dev.pth"
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
      root=$(git tag | grep release | sort -V | tail -n 1)
    fi
  else
    root='develop'
  fi
}

function setup_pyenv {
  TOOLS=$HOME/tools
  PYENV_ROOT="$TOOLS/pyenv"
  PATH="$TOOLS/local/bin:$PATH"
  PATH="$PYENV_ROOT/bin:$PATH"
  PATH="$PYENV_ROOT/libexec:$PATH"

  export PYENV_ROOT PATH

  eval "$(pyenv init -)"

  if [[ $? -gt 0 ]]
  then
    echo "could not execute pyenv init --shell. FAILED!"
    return 1
  fi

  return 0
}

setup_pyenv

function deactivate_if_needed {
  ver=$(pyenv version)

  echo "$ver" | cut -d ' ' -f 1 | grep -v 'system'

  if [[ $? -gt 0 ]]
  then
    return 0
  fi

  eval $(pyenv-sh-deactivate "${virt}")

  if [[ $? -ne 0 ]]
  then
    echo >/dev/stderr "pythonsh: deactivate of $ver failed!"
    return 1
  fi

  return 0
}

function latest_virtualenv_python {
  VERSION=$1

  LATEST_PYTHON=`pyenv versions | tr -s ' ' | sed -e 's,^ ,,' | cut -d '/' -f 1 | grep -E '[0-9]+\.[0-9]+\.[0-9]+' | sort -u -V -r | head -n 1`
  export LATEST_PYTHON

  echo "Python Latest Version: ${LATEST_PYTHON}"

  return 0
}

function candidate_virtualenv_python {
  VERSION=$1

  CANDIDATE_PYTHON=`pyenv install -l | tr -s ' ' | sed -e 's,^ ,,' | grep -E "^$VERSION" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -u -V -r | head -n 1`
  export CANDIDATE_PYTHON

  echo "Python Candidate version: ${CANDIDATE_PYTHON}"

  return 0
}

function show_all_python_versions {
  pyenv install -l | sed -e 's,^ *,,' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -u -V
}

function install_virtualenv_python {
  deactivate_if_needed || return 1

  # update the latest versions that build
  cd $PYENV_ROOT && git pull

  VERSION=$1

  system=$(uname)

  case $system in
    "Darwin")
       eval "$(/opt/dependencies/bin/brew shellenv)"
     ;;
  esac

  export CC="clang"

  echo "Updating Python interpreter: ${VERSION}..."

  (
      candidate_virtualenv_python ${VERSION}
      export PATH="${PYENV_ROOT}/versions/${CANDIDATE_PYTHON}/bin:${PATH}"

      ARCH=""

      if which arch
      then
          arch=$(arch)

          if [[ $arch = "arm64" ]]
          then
             ARCH="arch -arm64"
          fi
      fi

      eval "$ARCH pyenv install -v --skip-existing $VERSION"

      compile_status=$?

      if [[ $compile_status -eq 0 ]]
      then
          echo "Success!"
      else
          echo "ARCH is: $ARCH"
          echo "Compile Version is: $CANDIDATE_VERSION"
          echo "PATH for $VERSION is: $PATH"
          echo "CONFIGURE_OPTS is: $CONFIGURE_OPTS"
          echo "SSL_LOCATION is: $SSL_LOCATION"

          echo "pyenv install $VERSION FAILED with code $compile_status!"

          exit 1
      fi
  )

  if [[ $? -eq 0 ]]
  then
     latest_virtualenv_python $VERSION
  else
     echo "skipping virtual environment creation due to failed python $VERSION compile."
     return 1
  fi

  return 0
}

function install_virtualenv {
  LATEST=$1
  NAME=$2

  pyenv virtualenv "$LATEST" "$NAME"

  if [[ $? -ne 0 ]]
  then
    echo "virtualenv $LATEST $NAME - FAILED!"
    return 1
  fi

  echo "virtualenv $NAME done."
  return 0
}

function install_project_virtualenv {
  VERSION=$1

  ENV_ONE=$2
  ENV_TWO=$3

  install_virtualenv_python $VERSION || return 1

  echo "creating project virtual environments from $LATEST_PYTHON"

  if [[ -n $ENV_ONE ]]
  then
    echo -n "pythonsh [${LATEST_PYTHON}] - building: ${ENV_ONE}...."
    install_virtualenv $LATEST_PYTHON $ENV_ONE || return 1
  fi
  if [[ -n $ENV_TWO ]]
  then
    echo -n "pythonsh [${LATEST_PYTHON}] - building: ${ENV_TWO}...."
    install_virtualenv $LATEST_PYTHON $ENV_TWO || return 1
  fi

  return 0
}

function find_deps {
  pipdirs="pythonsh"

  for dep_dir in $(ls ${SOURCE} 2>/dev/null)
  do
    dep_dir="${SOURCE}/$dep_dir"

    echo >/dev/stderr "pythonsh find_deps: searching - ${dep_dir}"

    repos=`ls 2>/dev/null ${dep_dir}/*.pypi  | sed -e s,\s*,,g`

    if [[ -f "${dep_dir}/Pipfile" || -n $repos ]]
    then
      echo >/dev/stderr "pythonsh find_deps: found pipdir - ${dep_dir}"
      pipdirs="${pipdirs} ${dep_dir}"
    fi
  done

  site_dir=$(pyenv exec python -m site | grep 'site-packages' | grep -v USER_SITE | sed -e 's,^ *,,' | sed -e s/,//g | sed -e s/\'//g)

  echo >/dev/stderr "pipfile: using site dir: \"${site_dir}\""

  for dep_dir in $(ls "${site_dir}" 2>/dev/null)
  do
    dep_dir=${site_dir}/$dep_dir

    if [[ ! `basename $dep_dir` == 'examples' ]]
    then
      repos=`ls 2>/dev/null ${dep_dir}/*.pypi | sed -e s,\s*,,g`

      if [[ -f "${dep_dir}/Pipfile" || -n $repos ]]
      then
        pipdirs="${pipdirs} ${dep_dir}"
      fi
    fi
  done

  echo >/dev/stderr "pythonsh find_deps: procesing dirs: $pipdirs"
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

function deactivate_any {
  current=`pyenv version | grep -v -E '^system'`

  if [[ -n $current ]]
  then
    echo "deactivating current release: $current"
    pyenv deactivate
  else
    echo "no virtualenv active"
  fi
}

function prepare_buildset_environment {
  echo >/dev/stderr "pythonsh - buildset: creating virtualenv"

  deactivate_any

  build_env="${VIRTUAL_PREFIX}_build"

  if pyenv virtualenvs | grep $build_env
  then
    echo >/dev/stderr "deleting previous buildset environment $build_env"
    pyenv virtualenv-delete $build_env
  fi

  if install_project_virtualenv $PYTHON_VERSION $build_env
  then
    echo "buildset environment created: $build_env"
  else
    echo "ERROR: creating virtual environment $build_env"
    exit 1
  fi

  if pyenv activate "$build_env"
  then
    echo "pythonsh - buildset: activated build environement."
  else
    echo "pythonsh - buildset: could NOT activate build environment"
  fi

  echo >/dev/stderr "pythonsh - buildset: bootstrapping environment."

  $0 bootstrap
}


function build_buildset {
  echo >/dev/stderr "pythonsh - buildset: starting buildset $VERSION"

  prepare_buildset_environment

  echo >/dev/stderr "pythonsh - buildset: building project wheel."
  $0 build

  echo >/dev/stderr "pythonsh - buildset: starting set build in $setdir"

  setdir=buildset

  if [[ -d $setdir ]]
  then
    rm -r $setdir
    mkdir $setdir
  else
    mkdir $setdir
  fi

  mkset="pyutils/mkset.py"

  if [[ -f $mkset ]]
  then
    echo >/dev/stderr "pythonsh - buildset: using $mkset"
  else
    mkset="pythonsh/pyutils/mkset.py"
    echo >/dev/stderr "pythonsh - buildset: using $mkset"
  fi

  site=`pyenv exec python -c 'import site; print(site.getsitepackages()[0])'`
  echo >/dev/stderr "pythonsh - buildset: copying out packages: $site"

  for pkg in $(pyenv exec python $mkset)
  do
    pkg=`echo $pkg | sed -e 's,^\\s*,,'`

    if [[ -z "$pkg" ]]
    then
      continue
    fi

    echo >/dev/stderr "pythonsh - buildset: copying $pkg"
    cp -R $site/$pkg $setdir/
  done

  dist=$PWD/dist/
  test -d $dist || mkdir $dist

  for pkg in $(ls dist/*.whl)
  do
    echo >/dev/stderr "pythonsh - buildset: installing built package: $pkg"
    (cd $setdir && unzip $pkg)
  done

  find $setdir -name '*.pypi' -print | xargs rm
  find $setdir -name 'Pipfile' -print | xargs rm

  buildset=$dist/${BUILD_NAME}-set-${VERSION}-py3-none-any.whl

  (cd $setdir && zip -r $buildset *)

  echo "buildset done! $buildset"
}

function create_tag {
  TYPE=$1

  FEATURE=$2

  if [[ -z $FEATURE ]]
  then
    echo "tag-${TYPE} requires the feature as the first argument"
  fi

  MESSAGE=$3

  if [[ -z $MESSAGE ]]
  then
    echo "tag-${TYPE} requires description as the second argument"
  fi

  if git tag | grep "${TYPE}-${USER}/${FEATURE}"
  then
    COUNT=$(git tag | grep "${TYPE}-${USER}/${FEATURE}" | wc -l)

    COUNT=$((COUNT + 1))

    TAG_NAME="${TYPE}-${USER}/${FEATURE}(${COUNT})"
  else
    TAG_NAME="${TYPE}-${USER}/${FEATURE}(1)"
  fi

  echo "tag name is: $TAG_NAME"

  read -p "create tag? [y/n]: " choice

  if [[ $choice == "y" ]]
  then
    git tag -a $TAG_NAME -m $MESSAGE
  else
    echo "tag-alpha: aborting!"
    exit 1
  fi
}

function get_last_commit_type {
  if [[ $1 == "release" ]]
  then
    last=`git tag | grep release | sort -V | tail -n 1`
    git log --oneline "${last}..develop" | cut -d ' ' -f 2- | grep -E "^\(${2}\)"
  else
    root_to_branch
    git log --oneline "${root}..${branch}" | cut -d ' ' -f 2- | grep -E "^\(${2}\)"
  fi
}

function print_report {
  if [[ -n $features ]]
  then
    cat <<MESSAGE

* features

$features
MESSAGE
  fi

  if [[ -n $bugs ]]
  then
    cat <<MESSAGE

* bugs

$bugs
MESSAGE
  fi

  if [[ -n $fixes ]]
  then
    cat <<MESSAGE

* fixes

$fixes
MESSAGE
  fi

  if [[ -n $syncs ]]
  then
    cat <<MESSAGE

* syncs

$syncs
MESSAGE
  fi

  if [[ -n $refactor ]]
  then
    cat <<MESSAGE

* refactor

$refactor
MESSAGE
  fi
}

function check_python_environment {
  if $0 virtual-current
  then
    echo ">>>virtual environment found"
  else
    echo "ERROR: no virtual environment activated!"
    exit 1
  fi

  if pyenv exec python --version >/dev/null 2>&1
  then
    echo ">>> pyenv python found."
  else
    echo ">>> pyenv python NOT FOUND! exiting now!"
    exit 1
  fi
}

case $1 in
  "python-uninstall")
    shift
    version=$1

    exec pyenv uninstall $version
  ;;
  "version")
    echo "pythonsh version is: 1.1.1"
    ;;
  "tools-unix")
    # attempt to install git flow

    if [[ `uname` == "Darwin" ]]
    then
      if command -v brew >/dev/null 2>&1
      then
        brew install git-flow
      else
        if command -v ports >/dev/null 2>&1
        then
          ports install git-flow
        else
          echo "pythonsh: tools-unix - cannot find a way to install git-flow: brew,ports"
        fi
      fi
    else
      if command -v apt >/dev/null 2>&1
      then
        if command -v doas >/dev/null 2>&1
        then
          doas apt install git-flow libbz2-dev liblzma-dev libncurses-dev libreadline-dev libssl-dev libsqlite3-dev libffi-dev gcc autoconf automake libtool autotools-dev make zlib1g zlib1g-dev
        else
          sudo apt install git-flow libbz2-dev liblzma-dev libncurses-dev libreadline-dev libssl-dev libsqlite3-dev libffi-dev gcc autoconf automake libtool autotools-dev make zlib1g zlib1g-dev
        fi
      else
        echo "pythonsh: tools-unix - cannot find a way to install git-flow: all I know is apt"
      fi
    fi

    echo "installing pyenv for UNIX"

    TOOLS="$HOME/tools/"
    PYENV_ROOT="$TOOLS/pyenv"

    test -d "$TOOLS/local" || mkdir -p "$TOOLS/local"

    if test -d $PYENV_ROOT && test -d $PYENV_ROOT/.git
    then
      echo >/dev/stderr "pythonsh: updating PYENV_ROOT=${PYENV_ROOT}"
      (cd $PYENV_ROOT && git pull)
    else
      echo /dev/stderr "pythonsh: cloning pyenv into PYENV_ROOT=${PYENV_ROOT}"
      git clone https://github.com/pyenv/pyenv.git $PYENV_ROOT
    fi

    VIRTUAL="$TOOLS/pyenv-virtual"
    echo >/dev/stderr "pythonsh: installing pyenv-virtual for UNIX in ${VIRTUAL}"

    if test -d $VIRTUAL && test -d "$VIRTUAL/.git"
    then
      echo >/dev/stderr "pythonsh: updating pyenv-virtual"
      (cd $VIRTUAL && git pull && export PREFIX="$TOOLS/local" && ./install.sh)
    else
      echo >/dev/stderr "pythonsh: cloning pyenv-virtual into ${VIRTUAL}"
      git clone https://github.com/pyenv/pyenv-virtualenv.git $VIRTUAL
      (cd $VIRTUAL && export PREFIX="$TOOLS/local" && ./install.sh)
    fi
    ;;
  "tools-zshrc")
    cp pythonsh/zshrc.rc $HOME/.zshrc
    echo >/dev/stderr "replacing .zshrc with upstream version"
    ;;
  "tools-custom")
    echo >/dev/stderr "replacing .zshrc.custom with upstream version"
    cp pythonsh/zshrc.custom $HOME/.zshrc.custom
    ;;
  "tools-prompt")
    echo >/dev/stderr "installing standard prompt with pyenv and github support"
    cp pythonsh/zshrc.prompt $HOME/.zshrc.prompt
    ;;

  "tools-brew-init")
    test -d /opt/homebrew || sudo mkdir -p /opt/homebrew
    curl -L https://github.com/Homebrew/brew/tarball/master >/tmp/brew.xz
    sudo tar xJf /tmp/brew.xz --strip 1 -C /opt/homebrew
    sudo chown -R mattie /opt/homebrew
    ;;

  "tools-brew-upgrade")
    ARCH=$(arch)

    if [[ $ARCH = "arm64" ]]
    then
       arch -arm64 brew update
       arch -arm64 brew upgrade
    else
       brew update
       brew upgrade
    fi
  ;;
  "tools-brew-install")
    shift

    ARCH=$(arch)

    if [[ $ARCH = "arm64" ]]
    then
       arch -arm64 brew install $@
    else
       brew install $@
    fi
  ;;
  "tools-brew-rebuild")
    ARCH=$(arch)

    if [[ $ARCH = "arm64" ]]
    then
      brew list | xargs arch -arm64 brew reinstall
    else
      brew list | xargs brew reinstall
    fi
  ;;

  "dependencies-init")
    test -d /opt/dependencies || sudo mkdir -p /opt/dependencies
    curl -L https://github.com/Homebrew/brew/tarball/master >/tmp/brew.xz
    sudo tar xJf /tmp/brew.xz --strip 1 -C /opt/dependencies
    sudo chown -R mattie /opt/dependencies
  ;;

  "dependencies-upgrade")
    eval $(/opt/dependencies/bin/brew shellenv)

    ARCH=$(arch)

    if [[ $ARCH = "arm64" ]]
    then
       arch -arm64 brew update
       arch -arm64 brew upgrade
    else
       brew update
       brew upgrade
    fi
  ;;

  "dependencies-install")
    shift

    ARCH=$(arch)

    eval $(/opt/dependencies/bin/brew shellenv)

    if [[ $ARCH = "arm64" ]]
    then
       eval "arch -arm64 brew install $*"
    else
       eval "brew install $*"
    fi
  ;;

  "dependencies-python")
    DEPS="gnutls openssl readline ncurses gcc autoconf automake libtool pkg-config gettext"

    ARCH=$(arch)

    eval $(/opt/dependencies/bin/brew shellenv)

    if [[ $ARCH = "arm64" ]]
    then
       eval "arch -arm64 brew install $DEPS"
    else
       eval "brew install $DEPS"
    fi
  ;;

  #
  # virtual environments
  #
  "python-versions")
    show_all_python_versions
    ;;
  "project-virtual")
    install_project_virtualenv $PYTHON_VERSION "${VIRTUAL_PREFIX}_dev" "${VIRTUAL_PREFIX}_test" $@ || exit 1

    echo "you need to run switch_dev, switch_test, or switch_release to activate the new environments."
    ;;
  "global-virtual")
    shift
    NAME="$1"

    VERSION="${2:-$PYTHON_VERSION}"

    if [[ -z "$NAME" ]]
    then
      echo "global-virtual NAME (second argument) is missing."
      exit 1
    fi

    if [[ -z "$VERSION" ]]
    then
      echo "global-virtual: VERSION (first argument) is missing."
      exit 1
    fi

    install_project_virtualenv "$VERSION" "$NAME" || exit 1

    echo "you need to run \"switch_global $NAME\" to activate the new environment."
    ;;
  "virtual-destroy")
    shift

    if [[ -z $1 ]]
    then
      echo "pythonsh: give dev|test|release as the only argument of which env to delete"
      exit 1
    fi

    pyenv virtualenv-delete "${VIRTUAL_PREFIX}_${1}"
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
  "virtual-current")
    current=`pyenv virtualenvs | grep -E '^\*'`

    if [[ -z $current ]]
    then
      echo >/dev/stderr "pythonsh virtual-current: no virtualenv activated."
      exit 1
    fi

    echo "$current" | cut -d ' ' -f 2
    ;;
  #
  # initialization commands
  #
  "minimal")
    check_python_environment

    test -f Pipfile.lock || touch Pipfile.lock

    test -e pytest.ini || ln -s pythonsh/pytest.ini

    pipfile="pythonsh/Pipfile"

    pyenv exec python -m pip install pipenv ; PIPENV_PIPFILE="$pipfile" pyenv exec pipenv install --dev
    ;;
  "bootstrap")
    $0 minimal || exit 1

    # remove the un-needed minimal Pipfile.lock
    test -f pythonsh/Pipfile.lock && rm pythonsh/Pipfile.lock

    # generate the initial pipfile getting deps out of the source tree
    $0 pipfile >Pipfile || exit 1

    # do the basic install
    $0 all || exit 1

    # get all the pipfiles even in site-dir from installed packages
    $0 pipfile >Pipfile || exit 1

    $0 update || exit 1

    echo "bootstrap complete"
    ;;
  "test-install")
    # only use lockfile and dont install dev-packages, evidently sync
    # does install dev-packages

    pyenv exec python -m pip install pipenv

    pipenv install --ignore-pipfile

    echo "test-deps complete"
    ;;
  "pipfile")
    find_deps
    find_catpip

    eval "pyenv exec python $catpip pipfile $pipdirs"
    ;;
  "dockerfile")
    find_deps
    find_catpip

    eval "pyenv exec python $catpip dockerfile $pipdirs"
    ;;
  "project")
    find_deps
    find_catpip

    eval "pyenv exec python $catpip project $pipdirs"
    ;;

  #
  # python commands
  #
  "site")
    pyenv exec python -c 'import site; print(site.getsitepackages()[0])'
    ;;
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

    pipenv install --dev

    pyenv rehash
    pipenv lock

    # check for known security vulnerabilities
    pipenv check
    ;;
  "update")
    pipenv update

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
    pipenv check

    $0 project >pyproject.toml

    pyenv exec python -m build
    ;;
  "publish")
    pyenv exec twine upload --repository-url http://cracker.wifi:8080 dist/*
    ;;
  "buildset")
    build_buildset
    ;;
  "mkrelease")
    deactivate_any

    release_env="${VIRTUAL_PREFIX}_release"

    if pyenv virtualenvs | grep $release_env
    then
      echo >/dev/stderr "deleting previous buildset environment $release_env"
      pyenv virtualenv-delete $release_env
    fi

    install_project_virtualenv $PYTHON_VERSION "$release_env" || exit 1
    ;;
  "simple")
    shift

    PKG=$1
    shift

    if [[ -z $PKG ]]
    then
      echo >/dev/stderr "pythonsh: simple - no pkg or packages given"
    fi

    pyenv exec python -m pip install $PKG $@
    ;;
  "mkrunner")
    shift

    shdir=`dirname $0`

    dist="${shdir}/bin/mkrunner.sh"

    if [[ -f $dist ]]
    then
      $dist $@
      exit 0
    fi

    internal="${shdir}/../bin/mkrunner.sh"

    if [[ -f $internal ]]
    then
      $internal $@
      exit 0
    fi

    echo >/dev/stderr "pythonsh: could not find mkrunner.sh"
    exit 1
    ;;

  #
  # docker
  #

  "mklauncher")
    shift

    command -v mklauncher.sh >/dev/null 2>&1

    if [[ $? -ne 0 ]]
    then
      echo >/dev/stderr "pythonsh: could not find mklauncher.sh"
      exit 1
    fi

    if [[ -z $1 ]]
    then
      echo >/dev/stderr "pythonsh: no program given for mklauncher"
      exit 1
    fi

    mklauncher.sh $@
    ;;
  "docker-update")
    # copy pythonsh files
    cp py.sh python.sh docker/
    cp python.sh docker/python.sh

    # tangle the docker file
    (cd docker && org-compile.sh docker.org)
    mkdocker.sh "${DOCKER_VERSION}" >docker/Dockerfile

    #
    # copy over and generate run in environment scripts
    #

    cp bin/run-in-venv.sh docker/
    cp bin/batch-in-venv.sh docker/install.sh
    cp bin/run-in-venv.sh docker/install-pipenv.sh

    cat >>docker/install.sh <<INSTALLER
echo "HOME is \$HOME"
echo "USER is \$USER"
echo "PWD is \$PWD"
echo -n "whoami is: "
whoami

pyenv exec pipenv install
INSTALLER

    cp bin/batch-in-venv.sh docker/in-venv.sh
    cat >>docker/in-venv.sh <<VENV
echo "HOME is \$HOME"
echo "USER is \$USER"
echo "PWD is \$PWD"
echo -n "whoami is: "
whoami

source \$1
VENV

    # install pipenv
    echo "pyenv exec python -m pip install pipenv" >>docker/install-pipenv.sh
   ;;
   "docker-commit")
    git add docker/docker.org

    timestamp=`date`
    git commit -m "(update): generated Dockerfile @ \"$timestamp\""
    ;;
  "docker-build")
    $0 check

    if [[ -z $DOCKER_USER ]]
    then
      echo >/dev/stderr "pythonsh - docker: DOCKER_USER needs to be set. exiting."
      exit 1
    fi

    if [[ -z $DOCKER_VERSION ]]
    then
      echo >/dev/stderr "pythonsh - docker: DOCKER_VERSION needs to be set. exiting."
      exit 1
    fi

    echo "pythonsh - docker: building docker[${DOCKER_VERSION}]"

    (cd docker && dock-build.sh build)

    if [[ $? -ne 0 ]]
    then
      echo "docker FAILED! exit code was $?"
      exit 1
    fi

    echo "docker build success!: emitting Dockerfile.pythonsh-${DOCKER_VERSION} for this layer"
    echo "FROM ${DOCKER_USER}/pythonsh:${DOCKER_VERSION}" >Dockerfile.pythonsh-${DOCKER_VERSION}
    ;;
  "docker-release")
    shift
    MESSAGE=$1

    if [[ -z $MESSAGE ]]
    then
      echo >/dev/stderr "pythonsh docker-release - a message argument is missing."
      exit 1
    fi

    release="releases/docker-${DOCKER_VERSION}.tar"

    test -d releases || mkdir releases

    tar cf $release docker/
    git add $release

    git commit -m "Docker ${DOCKER_VERSION} release"

    git tag -a "docker-${DOCKER_VERSION}" -m "$MESSAGE"
    ;;
  "clean")
    find . -name '*.egg-info' -type d -print | xargs rm -r
    find . -name '__pycache__' -type d -print | xargs rm -r

    test -f pyproject.toml && rm pyproject.toml
    test -d buildset && rm -r buildset
    test -d dist && rm -r dist
    ;;

  #
  # modules
  #
  "modinit")
    git submodule init
    git submodule update --init
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
      exit 1
    fi
    ;;
  "modsync")
    if git pull --recurse-submodules
    then
      echo "pythonsh: update ok. please remember to test and commit."
    else
      echo "pythonsh: update failed. cleanup required."
      exit 1
    fi
    ;;
  "modupdate")
    shift

    if [[ -z $1 ]]
    then
      echo "pythonsh: update a submodule requires a submodule path"
      exit 1
    fi

    if git submodule update --remote $1
    then
      echo "pythonsh: update ok. please remember to test and commit."
    else
      echo "pythonsh: update failed. cleanup required."
      exit 1
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

    if git rm $1 && git rm -f $1
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
  "begin")
    shift
    name=$1

    if [[ -z $name ]]
    then
      echo "pythonsh begin: requires a name for a new feature branch as an argument"
      exit 1
    fi

    git flow feature start $name
    ;;
  "end")
    shift
    name=$1

    if [[ -z $name ]]
    then
      echo "pythonsh end: requires the name of the feature branch to close"
      exit 1
    fi

    git flow feature finish $name
    ;;
  "switch")
    shift
    name=$1

    if [[ -z $name ]]
    then
      echo "pythonsh switch: requires the name of the feature branch to switch to as an argument"
      exit 1
    fi

    git checkout "feature/$name"
    ;;    
  "beta")
    shift

    FEATURE=$1

    if [[ -z $FEATURE ]]
    then
      echo >/dev/stderr "pythonsh: tag-beta - a feature argument (1) is missing"
      exit 1
    fi

    MESSAGE=$2

    if [[ -z $MESSAGE ]]
    then
      echo >/dev/stderr "pythonsh tag-beta - a messsage argument (2) is missing."
      exit 1
    fi

    create_tag "beta" "$FEATURE" "$MESSAGE"
    ;;
  "track")
    shift

    REMOTE=$1

    if [[ -z $REMOTE ]]
    then
      echo >/dev/stderr "pythonsh: track - a remote (1) is missing"
      exit 1
    fi

    BRANCH=$2

    if [[ -z $BRANCH ]]
    then
      echo >/dev/stderr "pythonsh track - a branch (2) is missing."
      exit 1
    fi

    git branch -u $REMOTE/$BRANCH
    ;;
  "release-report")
    features=`get_last_commit_type release feat`
    bugs=`get_last_commit_type release bug`
    issues=`get_last_commit_type release issue`
    syncs=`get_last_commit_type release sync`
    fixes=`get_last_commit_type release fix`
    refactor=`get_last_commit_type release refactor`

    print_report
    ;;
  "status-report")
    features=`get_last_commit_type status feat`
    bugs=`get_last_commit_type status bug`
    issues=`get_last_commit_type status issue`
    syncs=`get_last_commit_type status sync`
    fixes=`get_last_commit_type status fix`
    refactor=`get_last_commit_type status refactor`

    print_report
    ;;
  "info")
    git branch -vv

    echo "[staged]"
    git diff --staged | diffstat

    echo "[changes]"
    git diff | diffstat

    echo "[untracked]"
    git ls-files -o --exclude-standard
    ;;
  "verify")
    exec git log --show-signature $@
    ;;
  "since")
    shift

    from=$1
    shift

    exec git log --since "$from" $@
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
  "releases")
    git tag | grep release | sort -V
    ;;
  "history")
    echo ">>>showing history"
    git log --oneline
    ;;
  "ahead")
    root_to_branch

    echo ">>>showing commits in $branch not $root (parent)"
    git log "${root}..${branch}" --oneline
    ;;
  "behind")
    root_to_branch

    echo ">>>showing commits in $root (parent) not $branch"
    git log "${branch}..${root}" --oneline
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
    check_python_environment

    echo "===> remember to pull deps with update if warranted <==="

    echo "===> fetching new commits from remote <==="
    git fetch origin develop

    echo "===> showing unmerged differences <===="

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

    # if python project check for python
    if [[ -f Pipfile ]]
    then
      check_python_environment

      find_catpip

      if eval "pyenv exec python $catpip test"
      then
        echo ">>> catpip found."
      else
        echo ">>> catpip NOT FOUND! exiting now!"
        exit 1
      fi
    fi

    $0 check

    echo "EDITOR is: $EDITOR ... correct?"

    read -p "Proceed? [y/n]: " proceed

    if [[ $proceed = "y" ]]
    then
      echo ">>> proceeding with release start!"
    else
      echo ">>> ABORT! exiting now!"
      exit 1
    fi

    VERSION="$1"

    echo -n "initiating git flow release start with version: $VERSION"

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

    echo ">>>recording release."

    test -d releases || mkdir releases

    if [[ -f Pipfile ]]
    then
      echo ">>>regenerating Pipfile."

      $0 pipfile >Pipfile
      git add Pipfile

      if [[ -f pyproject.toml ]]
      then
          echo ">>>regenerating pyproject.toml."

        $0 project >pyproject.toml
        git add pyproject.toml
      fi

      pipenv lock
      git add Pipfile.lock

      echo ">>>recording Pipfile and pyproject.toml."

      VER_PIP="releases/Pipfile-$VERSION"
      VER_LOCK="releases/Pipfile.lock-$VERSION"

      test -f Pipfile.lock && cp Pipfile.lock $VER_LOCK
      test -f Pipfile && cp Pipfile $VER_PIP

      test -f $VER_PIP && git add $VER_PIP
      test -f $VER_LOCK && git add $VER_LOCK
    fi

    VER_PYTHONSH="releases/python.sh-${VERSION}"

    echo ">>>recording python.sh"

    cp python.sh $VER_PYTHONSH

    if [[ $? -ne 0 ]]
    then
      echo ">>>FAILED! could not record python.sh into ${VER_PYTHONSH}"
      exit 1
    fi

    git add $VER_PYTHONSH

    echo ">>>commiting bump to to $VERSION"

    # don't do a automatic commit so a release summary can be inserted
    git commit

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
      echo "purging cache: $cache"
      rm -r $cache
    done

    for egg in $(find . -name '*.egg-info' -type d -print)
    do
      echo "purging build metadata: $egg"
      rm -r $egg
    done
    ;;
  "help"|""|*)
    cat <<HELP
python.sh

[tools commands]

tools-unix    = install pyen and pyenv virtual from source on UNIX (call again to update)

tools-zshrc   = install hombrew, pyenv, and pyenv switching commands into .zshrc
tools-custom  = install zshrc.custom
tools-prompt  = install prompt support with pyeenv, git, and project in the prompt

brew-upgrade  = upgrade brew packages

tools-brew-init     = initialize the /opt/homebrew homebrew repository
tools-brew-upgrade  = upgrade the /opt/homebrew repository
tools-brew-install  = install into /opt/homebrew a list of packages
tools-brew-rebuild  = rebuild packages in /opt/homebrew

dependencies-init     = initialize /opt/dependencies for stable and minimal deps to compile against
dependencies-upgrade  = upgrade /opt/dependencies 
dependencies-install  = install into /opt/dependencies a list of packages
dependencies-python   = install into /opt/dependencies python dependencies

[virtual commands]

python-versions  = list the available python versions
python-uninstall <version> = uninstall version
project-virtual  = create: dev and test virtual environments from settings in python.sh
global-virtual   = (NAME, VERSION): create NAME virtual environment, VERSION defaults to PYTHON_VERSION

virtual-destroy  = destroy a project-virtual: specify -> dev|test|release

project-destroy  = delete all the project virtual edenvironments
global-destroy   = delete a global virtual environment

virtual-list     = list virtual environments
virtual-current  = show the current virtual environment if any

[initialization]

minimal          = pythonsh only bootstrap for projects with only pythonsh deps
bootstrap        = two stage bootstrap generate pipfile, install source deps, install pkg deps
pipfile          = generate a pipfile from all of the packages in the source tree + pythonsh + site-packages deps
project          = generate a pyproject.toml file
test-install     = install packages only, from Pipfile.lock. This is for installing packages into the
                   test environment
show-paths = list .pth source paths
add-paths  = install .pth source paths into the python environment
rm-paths   = remove .pth source paths
site       = print out the path to site-packages

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
simple     = <pkg> do a simple pyenv pip install without pipenv

[build]

publish    = upload to cracker.local all packages in dist/*
build      = build packages
buildset   = build a package set
mkrelease  = make the release environment
mkrunner   = <program> <args....> make a runner that sets/restores environment for
             host python commands

[docker]

mklauncher     = <program> <args....> make a simple launcher for python docker

docker-update  = regenerate the Dockerfile from the .org file
docker-commit  = commit the .org dockerfile
docker-build   = build the PythonSh docker layer
docker-release = record a docker release with <MESSAGE>

dockerfile = generate a pipfile with additional docker packages.
mkrunner   = execute mkrunner.sh to build a runner

[submodule]

modinit             = initialize and pull all submodules
modadd <1> <2> <3>  = add a submodule where 1=repo 2=branch 3=localDir (commit after)
modupdate <module>  = pull the latest version of the module
modsync             = pull and sync all modules to checked out commits
modrm  <submodule>  = delete a submodule
modall              = update all submodules

[version control]

begin  <name> = start feature branch <name>
end    <name> = close feature branch <name>
switch <name> = switch to feature branch <name>
track <1> <2>  = set upstream tracking 1=remote 2=branch
beta       = <feat> <msg> = create a beta tag with the devel branch feature and message
info       = show branches, tracking, and status
verify     = show log with signatures for verification
status     = git state, submodule state, diffstat for changes in tree
since      = <DATE> pull logs since date, extra <ARGS...> are passed
fetch      = fetch main, develop, and current branch
pull       = pull current branch no ff
staged     = show staged changes
merges     = show merges only
releases   = show releases (tags)
history    = show commit history
summary    = show diffstat of summary between feature and develop or last release and develop
delta      = show diff between feature and develop or last release and develop
ahead      = show log of commits in branch but not in parent
behind     = show log of commit in parent but not branch

release-report  = generate a report of changes since last release
status-report = generate a report of changes ahead of the trunk

graph      = show history between feature and develop or last release and develop
upstream   = show upstream changes that havent been merged yet
sync       = merge from the root branch commits not in this branch no ff

[release]

check      = fetch main, develop from origin and show log of any pending changes
start      = initiate an EDITOR session to update VERSION in python.sh, reload config,
             snapshot Pipfile if present, and start a git flow release with VERSION

             for the first time pass version as an argument e.g: "./py.sh start 1.0.0"

release    = execute git flow release finish with VERSION
upload     = push main and develop branches and tags to remote

[misc]

purge      = remove all the __pycache__ dirs
HELP
    ;;
esac

exit 0

#! /usr/bin/env bash

# this will put us in bin/
PYTHONSH=$(dirname $0)
# this will put is in the pythonsh base directory
PYTHONSH_BASE=$(dirname "$PYTHONSH")

PYTHONSH_SHELL="${PYTHONSH_BASE}/shell/"
PYTHONSH_UTILS="${PYTHONSH_BASE}/pyutils/"
PYTHONSH_BOOTSTRAP="${PYTHONSH_BASE}/bootstrap"

PYTHONSH_BREW=""

PYTHONSH_SYSTEM=$(uname)

PYTHON_ARCH=""
PYTHON_ARCH_COMMAND=""

EMACS_BREW="/opt/emacs/"
DEP_BREW="/opt/dependencies/"

case $PYTHONSH_SYSTEM in
  "Darwin")
    PYTHONSH_BREW="/opt/dependencies"

    if which arch >/dev/null 2>&1
    then
      PYTHON_ARCH=$(arch)

      if [[ $PYTHONSH_ARCH == "arm64" ]]
      then
        PYTHON_ARCH_COMMAND="arch -arm64"
      fi
    fi
  ;;
esac

# load local pythonsh configuaration
if [[ -f python.sh ]]
then
  source python.sh
else
  echo >/dev/stderr "py.sh: WARNING python.sh configuration not found in current directory... all python commands will break!"
fi


if [[ -z $VIRTUAL_PREFIX ]]
then
  echo >/dev/stderr "py.sh: WARNING - VIRTUAL_PREFIX not set, python commands will not work!"
fi

if [[ -z $PYTHON_VERSION ]]
then
  echo >/dev/stderr "py.sh: WARNING - PYTHON_VERSION not set - python commands will not work!"
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

function setup_pyenv {
  TOOLS=$HOME/tools
  PYENV_ROOT="$TOOLS/pyenv"

  PATH="$TOOLS/local/bin:$PATH"
  PATH="$PYENV_ROOT/bin:$PATH"
  PATH="$PYENV_ROOT/libexec:$PATH"

  export PYENV_ROOT PATH

  if ! command -v pyenv >/dev/null 2>&1
  then
    echo >/dev/stderr "py.sh: pyenv not found! will continue, but python commands will fail."
    return 1
  fi

  eval "$(pyenv init -)"

  if [[ $? -gt 0 ]]
  then
    echo >/dev/stderr "py.sh: pyenv init --shell. FAILED!"
    return 2
  fi

  return 0
}

setup_pyenv

if [[ $? -eq 2 ]]
then
  echo >/dev/stderr "py.sh: setup_pyenv had a hard fail. exiting!"
  exit 1
fi

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

  candidate_virtualenv_python $VERSION

  BEST_PYTHON=$VERSION
  BEST_VERSION=$CANDIDATE_PYTHON

  echo "pythonsh: attempting install of python $BEST_PYTHON version $BEST_VERSION"
  VERSION_LOCATION="${PYENV_ROOT}/versions/${CANDIDATE_PYTHON}"

  CC="gcc"

  case $PYTHONSH_SYSTEM in
    "Darwin")
      eval $(${PYTHONSH_BREW}/bin/brew shellenv)
      CC="clang"
      export DYLD_LIBRARY_PATH="${VERSION_LOCATION}/lib:${DYLD_LIBRARY_PATH}"
    ;;
  esac

  CPPFLAGS="-I${VERSION_LOCATION}/include" 
  LDFLAGS="-L${VERSION_LOCATION}/lib"

  PATH="${VERSION_LOCATION}/bin:${PATH}"

  export PPFLAGS LDFLAGS CC PATH BEST_PYTHON BEST_VERSION

  echo "Updating Python interpreter: ${BEST_VERSION}"

 (
    eval $PYTHONSH_ARCH pyenv install -v --skip-existing $BEST_VERSION
    compile_status=$?

    if [[ $compile_status -ne 0 ]]
    then
    echo "pythonsh: pyenv install $BEST_VERSION FAILED with code $compile_status"

      echo "ARCH is: $PYTHON_ARCH"

      echo "Compile Version is: $BEST_VERSION"
      echo "PATH for $VERSION is: $PATH"
      echo "CONFIGURE_OPTS is: $CONFIGURE_OPTS"
      echo "SSL_LOCATION is: $SSL_LOCATION"

      return 1
    fi

    echo "pythonsh: Success! version = ${BEST_VERSION}"
    latest_virtualenv_python $BEST_VERSION
  )

  return 0
}

function install_virtualenv {
  LATEST=$1
  NAME=$2

  echo "pythonsh: installing virtualenv $NAME"

  pyenv virtualenvs | grep "$NAME" >/dev/null
  if [[ $? -eq 0 ]]
  then
    echo "pythonsh: deleting existing virtual environment $NAME"
    pyenv virtualenv-delete $NAME
  fi

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
  ENV_THREE=$4

  echo "pythonsh: install_project_virtualenv one = $ENV_ONE two = $ENV_TWO three = $ENV_THREE"

  install_virtualenv_python $VERSION
  
  if [[ $? -ne 0 ]]
  then
    exit 1
  fi

  echo "creating project virtual environments from $BEST_VERSION"

  echo "pythonsh: building environment: $ENV_ONE from $BEST_VERSION"

  install_virtualenv $BEST_VERSION $ENV_ONE
   
   if [[ $? -ne 0 ]]
   then
     exit 1
  fi

  if [[ -n $ENV_TWO ]]
  then
    echo "pythonsh: building environment: ${ENV_TWO} from $BEST_VERSION"

    install_virtualenv $BEST_VERSION $ENV_TWO

    if [[ $? -ne 0 ]]
    then
      exit 1
    fi
  fi

  if [[ -n $ENV_THREE ]]
  then
    echo "pythonsh: building environment: ${ENV_THREE} from $BEST_VERSION"

    install_virtualenv $BEST_VERSION $ENV_THREE

    if [[ $? -ne 0 ]]
    then
      exit 1
    fi
  fi

  return 0
}

function find_deps {
  pipdirs="${PYTHONSH_BASE}/bootstrap"

  if [[ -z $SOURCE ]]
  then
    echo "pythonsh: warning no SOURCE setting in python.sh file. Rerun pipfile command to generate a new Pipfile"
    return 0
  fi

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
  catpip="${PYTHONSH_UTILS}/catpip.py"

  if command -v catpip >/dev/null 2>&1
  then
    echo >/dev/stderr "pipfile: using installed catpip: catpip"
    catpip="catpip"
  elif [[ -f ${catpip} ]]
  then
    echo >/dev/stderr "pipfile: using distributed catpip: ${catpip}"
  else
    echo >/dev/stderr "pythonsh: (pipfile): can\'t find catpip.py... exiting with error."
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
  "version")
    echo "pythonsh version is: 1.1.1"
    ;;
  "tools-python")
    # attempt to install git flow

    if [[ `uname` == "Darwin" ]]
    then
      if command -v brew >/dev/null 2>&1
      then
        brew install git-flow-avh
      else
        if command -v ports >/dev/null 2>&1
        then
          ports install git-flow-avh
        else
          echo "pythonsh: tools-python - cannot find a way to install git-flow: brew,ports"
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
        echo "pythonsh: tools-python - cannot find a way to install git-flow: all I know is apt"
      fi
    fi

    echo >/dev/stderr "pythonsh: installing tools for python"

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
  "dependencies-init")
    test -d /opt/dependencies || sudo mkdir -p /opt/dependencies
    curl -L https://github.com/Homebrew/brew/tarball/master >/tmp/brew.xz
    sudo tar xJf /tmp/brew.xz --strip 1 -C /opt/dependencies
    sudo chown -R mattie /opt/dependencies
  ;;

  "dependencies-upgrade")
    eval $(${DEP_BREW}bin/brew shellenv)

    $PYTHON_ARCH_COMMAND brew update
    $PYTHON_ARCH_COMMAND brew upgrade
  ;;

  "dependencies-install")
    shift

    eval $(${DEP_BREW}bin/brew shellenv)
    $PYTHON_ARCH_COMMAND brew install $*
  ;;

  "dependencies-python")
    DEPS="gnutls openssl readline ncurses gcc autoconf automake libtool pkg-config gettext"

    eval $(${DEP_BREW}bin/brew shellenv)

    OPENSSL=$(${DEP_BREW}bin/brew --prefix openssl)

    $PYTHON_ARCH_COMMAND brew install $DEPS
  ;;

  #
  # virtual environments
  #
  "python-versions")
    show_all_python_versions
  ;;
  "python-uninstall")
    shift
    version=$1

    exec pyenv uninstall $version
  ;;
  "project-virtual")
    install_project_virtualenv $PYTHON_VERSION "${VIRTUAL_PREFIX}_dev" "${VIRTUAL_PREFIX}_test" || exit 1

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

    test -e pytest.ini || cp ${PYTHONSH_BASE}pytest.ini .

    pipfile="${PYTHONSH_BOOTSTRAP}/Pipfile"

    echo >/dev/stderr "pythonsh: bootstrap Pipfile = $pipfile"

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

    echo >/dev/stderr "pythonsh: bootstrap complete"
    ;;
  "test-install")
    # only use lockfile and dont install dev-packages, evidently sync
    # does install dev-packages

    pyenv exec python -m pip install pipenv

    pipenv install --ignore-pipfile

    echo >/dev/stderr "pythonsh: test-deps complete"
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
  # release environment
  #
  "check")
    if [[ -n $VIRTUALENV_PREFIX ]]
    then
      check_python_environment
    fi

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

    echo ">>>commit with release notes for version $VERSION"

    # don't do a automatic commit so a release summary can be inserted
    git commit

    echo "ready for release finish: please finish with py.sh release once you are ready"
    ;;
  "release")
    git flow release finish $VERSION || exit 1
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
    if [[ -n $2 ]]
    then
      filter="$2"
    else
      filter='\.*'
    fi

    echo "filter is $filter"

    cat <<HELP | grep "$filter"
py.sh

[tools commands]

tools-python  = install pyen and pyenv virtual from source on UNIX (call again to update)

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

[paths]

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

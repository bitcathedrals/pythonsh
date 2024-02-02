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
      test -d $HOME/tools || mkdir $HOME/tools
      cd $HOME/tools

      git clone https://github.com/pyenv/pyenv.git pyenv

      ln -s $HOME/tools/pyenv ~/.pyenv

      git clone https://github.com/pyenv/pyenv-virtualenv.git pyenv-virtual

      test -d $HOME/tools/local || mkdir -p $HOME/tools/local

      (cd pyenv-virtual && export PREFIX=$HOME/tools/local && ./install.sh)

      echo "export PATH=\$HOME/tools/local/bin:$PATH" >>~/.zshrc.custom

      echo "installation completed"
    ;;
    "tools-zshrc")
       echo "adding shell code to .zshrc, you may need to edit the file."

        cat >>~/.zshrc <<SHELL

test -f \$HOME/.zshrc.custom && source \$HOME/.zshrc.custom

if [[ -f \$HOME/homebrew/bin/brew ]]
then
    eval "\$(\$HOME/homebrew/bin/brew shellenv)"
else
   which brew >/dev/null 2>&1 && eval "\$(brew shellenv)"
fi

export PYENV_ROOT="\$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="\$PYENV_ROOT/bin:\$PATH"
eval "\$(pyenv init -)"

export PYENV_VIRTUALENV_DISABLE_PROMPT=1

test -f \$HOME/.zshrc.prompt && source \$HOME/.zshrc.prompt

function switch_dev {
    if test -f python.sh
    then
        source python.sh
        echo ">>>switching to \${VIRTUAL_PREFIX} dev"

        if pyenv virtualenvs | grep '*'
        then
            pyenv deactivate
        fi

        pyenv activate \${VIRTUAL_PREFIX}_dev
    else
        echo "cant find python.sh - are you in the project root?"
    fi;
}

function switch_test {
    if test -f python.sh
    then
        source python.sh
        echo ">>>switching to \${VIRTUAL_PREFIX} test"

        if pyenv virtualenvs | grep '*'
        then
            pyenv deactivate
        fi

        pyenv activate \${VIRTUAL_PREFIX}_test
    else
        echo "cant find python.sh - are you in the project root?"
    fi;
}

function switch_release {
    if test -f python.sh
    then
        source python.sh
        echo ">>>switching to \${VIRTUAL_PREFIX} release"

        if pyenv virtualenvs | grep '*'
        then
            pyenv deactivate
        fi

        pyenv activate \${VIRTUAL_PREFIX}_release
    else
        echo "cant find python.sh - are you in the project root?"
    fi;
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

        if pyenv virtualenvs | grep '*'
        then
           pyenv exec python -m pip install -U pip
           pyenv exec python -m pip install -U pipenv
        fi
    ;;
#
# virtual environments
#

    "virtual-install")
        pyenv install --skip-existing "$PYTHON_VERSION"

        FEATURE=`echo $PYTHON_VERSION | cut -d ':' -f 1`
        echo "Installing Python feature verrsion: $FEATURE"

        LATEST=`pyenv versions | grep -E "^ *$FEATURE" | sort | tail -n 1 | sed -e 's,^ *,,'`

        echo "installing $LATEST to $VIRTUAL_PREFIX"

        pyenv virtualenv "$LATEST" "${VIRTUAL_PREFIX}_dev"
        pyenv virtualenv "$LATEST" "${VIRTUAL_PREFIX}_test"
        pyenv virtualenv "$LATEST" "${VIRTUAL_PREFIX}_release"

    ;;
    "virtual-destroy")
        pyenv virtualenv-delete "${VIRTUAL_PREFIX}_dev"
        pyenv virtualenv-delete "${VIRTUAL_PREFIX}_test"
        pyenv virtualenv-delete "${VIRTUAL_PREFIX}_release"
    ;;

    "virtual-list")
        pyenv virtualenvs
    ;;

    "bootstrap")
       pyenv exec python -m pip install pipenv
       pyenv exec python -m pip install --upgrade pip

       test -f Pipfile.lock || touch Pipfile.lock
       export PIPENV_PIPFILE='pythonsh/Pipfile'; pipenv install
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

    "aws")
        export $(printf "AWS_ACCESS_KEY_ID=%s AWS_SECRET_ACCESS_KEY=%s AWS_SESSION_TOKEN=%s" \
                    $(aws sts assume-role \
                    --role-arn $AWS_ROLE \
                    --role-session-name DevCloudFormationSession \
                    --profile $AWS_PROFILE \
                    --query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" \
                    --output text))

        pyenv exec python -m awscli --region $REGION $@
    ;;

#
# packages
#
    "pipfile")
      pipdirs="pythonsh"

      for project_dir in $(find src -type d -depth 1 -print)
      do
        pkg_dir="${project_dir}/${project_dir}/"

        if [[ -f "${pkg_dir}/Pipfile" ]]
        then
          pipdirs="${pipdirs} ${pkg_dir}"
        fi
      done

      eval "pyenv exec python pythonsh/pyutils/catpip.py $pipdirs"
    ;;
    "versions")
        pyenv version
        pyenv exec python --version
        pipenv graph
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

        test -f Pipfile.lock && mv Pipfile.lock $VER_LOCK
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
tools-unix    = install pyen and pyenv virtual from source on UNIX

tools-update-macos  = update tools from homebrew

tools-zshrc         = install hombrew, pyenv, and pyenv switching commands into .zshrc
tools-prompt        = install prompt support with pyeenv, git, and project in the prompt

tools-update-macos  = update the pyenv tools and update pip/pipenv in the current virtual machine


[virtual commands]

virtual-install  = install a pyenv virtual environment
virtual-destroy  = delete the pyenv virtual environment
virtual-list     = list virtual environments

bootstrap        = do a pip install of deps for pythonsh python utilities
pipfile          = generate a pipfile from all of the packages in the source tree + pythonsh

switch_dev       = switch to dev virtual environment
switch_test      = switch to test virtual environment
switch_release   = switch to release virtual environment

[python commands]

test    = run pytests
show-paths = list .pth source paths
add-paths  = install .pth source paths into the python environment
rm-paths   = remove .pth source paths
python  = execute python in pyenv
repl    = execute ptpython in pyenv
run     = run a command in pyenv

[aws commands]

aws       = execute a aws cli command

[package commands]

versions   = display the versions of python and installed packages
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

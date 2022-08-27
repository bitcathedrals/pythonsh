#! /bin/bash

source python.sh || exit 1

function add_src {
    site=`pyenv exec python -c 'import site; print(site.getsitepackages()[0])'`

    echo "include_src: setting dev.pth in $site/dev.pth"

    test -d $site || mkdir -p $site

    cat python.paths | sed -e "s,^,$PWD/," >"$site/dev.pth"
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
        root=$(git tag | tail -n 1)

    else 
        root='develop'       
    fi
}

case $1 in

#
# tooling
#
    "tools-install")
        echo "installing brew tools"

        brew update

        brew install pyenv
        brew install pyenv-virtualenv
        brew install git-flow
    ;;
    "tools-zshrc")
       echo "adding shell code to .zshrc, you may need to edit the file."

        cat >>~/.zshrc <<SHELL
eval "\$(homebrew/bin/brew shellenv)"

export PYENV_ROOT="\$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="\$PYENV_ROOT/bin:\$PATH"
eval "\$(pyenv init -)"

export EDITOR=$EDITOR

function dev {
    if test -f python.sh
    then
        echo "switching to \${VIRTUAL_PREFIX} dev"
        source python.sh

        if pyenv virtualenvs | grep '*'
        then
            pyenv deactivate
        fi

        pyenv activate \${VIRTUAL_PREFIX}_dev
    else
        echo "cant find python.sh - are you in the project root?"
    fi;
}

function release {
    if test -f python.sh
    then
        echo "switching to \${VIRTUAL_PREFIX} release"
        source python.sh

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
    "tools-upgrade")
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

        LATEST=$(pyenv versions | grep -E '^ *\d+\.\d+\.\d+$' | sed 's/ *//g')

        echo "installing $LATEST to $VIRTUAL_PREFIX"

        pyenv virtualenv "$LATEST" "${VIRTUAL_PREFIX}_release"
        pyenv virtualenv "$LATEST" "${VIRTUAL_PREFIX}_dev"
    ;;
    "virtual-destroy")
        pyenv virtualenv-delete "${VIRTUAL_PREFIX}_release"
        pyenv virtualenv-delete "${VIRTUAL_PREFIX}_dev"
    ;;

    "virtual-list")
        pyenv virtualenvs
    ;;

#
# python commands
#

    "test")
        pyenv exec python -m pytest tests
    ;;
    "paths")
        shift
        add_src
        pyenv exec python -c "import sys; print(sys.path)"
    ;;
    "python")
        shift
        pyenv exec python $@
    ;;
    "run")
        shift
        pyenv exec $@ 
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

    "versions")
        pyenv version
        pyenv exec python --version
        pipenv graph
    ;;
    "update")
        pyenv exec python -m pipenv install --skip-lock
        pyenv exec python -m pyenv rehash
    ;;
    "update-all")
        pyenv exec python -m pip install -U pip
        pyenv exec python -m pip install -U pipenv
        pyenv exec python -m pipenv install --dev --skip-lock
        pyenv rehash
    ;;
    "list")
        pyenv exec python -m pipenv graph
    ;;
    "build")
        pyenv exec python -m build

        find . -name '*.egg-info' -type d -print | xargs rm -r 
        find . -name '__pycache__' -type d -print | xargs rm -r  
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
        root_to_branch

        if [[ $branch == "develop" ]]
        then
            root="main"
        else 
            root="develop"
        fi

        git fetch origin main
        git fetch origin develop

        echo ">>>showing upstream changes from: ${branch}->${root}"
        git log --no-merges ${root} ^${branch} --oneline
    ;;
    "sync")
        root_to_branch
        echo ">>>syncing from parent to branch ${root}->${branch}"
    
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
        echo -n "please edit python.sh with an updated version in 3 seconds."
        sleep 1
        echo -n "."
        sleep 1
        echo -n "."
        sleep 1

        $EDITOR python.sh || exit 1
        source python.sh

        git add python.sh
        git commit -m "bump to version $VERSION"

        if git diff --quiet
        then
            echo "working tree clean - proceeding with release: $VERSION"
        else
            echo "working tree dirty - terminating release:"

            git status
            exit 1
        fi

        test -d releases || mkdir releases
        test -f Pipfile && pyenv exec python -m pipenv lock

        test -f Pipfile.lock && mv Pipfile.lock releases/Pipfile.lock-$VERSION
        test -f Pipfile && cp Pipfile releases/Pipfile-$VERSION

        echo -n "initiating git flow release start with version: $VERSION in 3 seconds."
        sleep 1
        echo -n "."
        sleep 1
        echo -n "."
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

#
# my machine specific deploy commands
#

    "deploy-m1")
        pyenv exec python -m build

        find . -name '*.egg-info' -type d -print | xargs rm -r 
        find . -name '__pycache__' -type d -print | xargs rm -r 

        DIST_PATH="/Users/michaelmattie/coding/python-packages/"
        PKG_PATH="$DIST_PATH/simple/cfconfig"
        BEAST="michaelmattie@beast.local"

        ssh $BEAST "test -d $PKG_PATH || mkdir $PKG_PATH"
        scp dist/* "$BEAST:$PKG_PATH/"
    ;;
    "deploy-intel")
        pyenv exec python -m build

        find . -name '*.egg-info' -type d -print | xargs rm -r 
        find . -name '__pycache__' -type d -print | xargs rm -r 

        DIST_PATH="/Users/michaelmattie/coding/python-packages/"
        PKG_PATH="$DIST_PATH/simple/cfconfig"

        test -d $PKG_PATH || mkdir $PKG_PATH
        cp dist/* $PKG_PATH/
    ;;
    "help"|""|*)
        cat <<HELP
python.sh

[tools commands]

tools-install = install tools from homebrew
tools-update  = update tools from homebrew
tools-zshrc   = install hombrew, pyenv, and pyenv switching commands into .zshrc

[virtual commands]

virtual-install  = install a pyenv virtual environment
virtual-destroy  = delete the pyenv virtual environment
virtual-list     = list virtual environments

dev              = switch to dev environment
release          = switch to release environment

[python commands]

test    = run pytests
paths   = install .pth source paths into the python environment
python  = execute python in pyenv
run     = run a command in pyenv

[aws commands]

aws       = execute a aws cli command

[package commands]

versions   = display the versions of python and installed packages
update     = update installed packages
update-all = update pip and installed
list       = list installed packages

build      = build packages

[version control]

status     = git state, submodule state, diffstat for changes in tree
fetch      = fetch main, develop, and current branch
pull       = pull current branch no ff
sub        = update submodules
staged     = show staged changes

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

[deploy]

deploy-m1    = deploy packages on the m1 machine
deploy-intel = deploy packages on the intel machine
HELP
    ;;
esac

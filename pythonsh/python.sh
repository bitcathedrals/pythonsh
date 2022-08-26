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

case $1 in

#
# tooling
#
    "install-tools")
        brew update

        brew install pyenv
        brew install pyenv-virtualenv
        brew install git-flow
    ;;
    "update-tools")
        brew update

        brew upgrade pyenv
        brew upgrade pyenv-virtualenv
        brew upgrade git-flow
    ;;

#
# virtual environments
#

    "virtual-install")
        pyenv install --skip-existing "$PACKAGE_PYTHON_VERSION"

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
    ;;
    "fetch")
        git fetch
        git fetch origin main
        git fetch origin develop
    ;;
    "pull")
        git pull --recurse-submodules
    ;;
    "sub")
        git submodule update --remote
    ;;
    "staged")
        git diff --cached
    ;;
    "summary")
        branch=$(git branch | grep '*' | cut -d ' ' -f 2)

        if echo "$branch" | grep feature
        then
            root='develop'
        else 
            root=$(git tag | tail -n 1)
        fi

        git diff "${root}..${branch}" --stat
    ;;
    "delta")
        branch=$(git branch | grep '*' | cut -d ' ' -f 2)

        if echo "$branch" | grep feature
        then
            root='develop'
        else 
            root=$(git tag | tail -n 1)
        fi

        git diff "${root}..${branch}"
    ;;


#
# release environment
#
    "dev-start")
        test -d releases || mkdir releases
        pyenv exec python -m pipenv lock

        mv Pipfile.lock releases/Pipfile.lock-$VERSION
        cp Pipfile releases/Pipfile-$VERSION
    ;;
    "dev-finish")
        git push --all
        git push --tags
    ;;
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
    "help")
        cat <<HELP
python.sh

[tools commands]

install-tools = install tools from homebrew
update-tools  = update tools from homebrew

[virtual commands]

virtual-install  = install a pyenv virtual environment
virtual-destroy  = delete the pyenv virtual environment
virtual-list     = list virtual environments

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

status     = vc status
fetch      = fetch main, develop, and current branch
pull       = pull current branch and
sub        = update submodules

[release]

dev-start  = start a release by freezing the Pip files
dev-finish = push branches and tags to remote

[deploy]

deploy-m1    = deploy packages on the m1 machine
deploy-intel = deploy packages on the intel machine
HELP
    ;;
    *)
        echo "unknown command."
    ;;
esac

#! /usr/bin/env bash

case $1 in
  "finish")
    shift

    test -e py.sh || ln -s pythonsh/pythonsh/python.sh py.sh

    git submodule init
    git submodule update --init
   ;;
   "private")
     shift
     git submodule add -f git@github.com:bitcathedrals/pythonsh.git pythonsh $@

     $0 finish
   ;;
   "public")
     shift
     git submodule add -f https://github.com/bitcathedrals/pythonsh.git pythonsh $@

     $0 finish
   ;;

   "remove")
     git rm pythonsh
     git rm --cached pythonsh
     rm -rf pythonsh
     rm -rf .git/modules/pythonsh

     echo "pysh-install.sh: delete the entry from .gitmodules"
   ;;
esac

#! /usr/bin/env bash

case $1 in
	"clone")
		shift
		git submodule update --init $@
	;;
	"install")
		shift
		git submodule add -f git@github.com:coderofmattie/pythonsh.git pythonsh $@
		test -e py.sh || ln -s pythonsh/pythonsh/python.sh py.sh
	;;
	"public")
		shift
		git submodule add -f https://github.com/coderofmattie/pythonsh.git pythonsh $@
		test -e py.sh || ln -s pythonsh/pythonsh/python.sh py.sh
	;;
	"remove")
		git rm pythonsh
		git rm --cached pythonsh
		rm -rf pythonsh
		rm -rf .git/modules/pythonsh

		echo "delete the entry from .git/config"
	;;
esac

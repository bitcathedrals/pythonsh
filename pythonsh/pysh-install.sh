#! /bin/bash

case $1 in
	"clone")
		git submodule update --init
	;;
	"install")
		git submodule add git@github.com:coderofmattie/pythonsh.git pythonsh
		ln -s pythonsh/pythonsh/python.sh py.sh
	;;
esac

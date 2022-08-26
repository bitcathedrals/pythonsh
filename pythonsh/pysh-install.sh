#! /bin/bash

case $1 in
	"clone")
		shift
		git submodule update --init $@
	;;
	"install")
		shift
		git submodule add -f git@github.com:coderofmattie/pythonsh.git pythonsh $@
		echo "    ignore = dirty" >>.gitmodules
		ln -s pythonsh/pythonsh/python.sh py.sh

	;;
esac

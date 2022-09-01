#
# prompt.sh: set a prompt with the pyenv virtual machine and the github branch
#

virtual_environment="?"
git_branch="?"
project_name="?"

function get_pyenv {
	environment=`pyenv virtualenvs | grep '*'`

	if [[ -z $environment ]]
	then
		virtual_environmeent="none"
	else
		virtual_environment=`echo $environment | cut -d ' ' -f 2`
	fi
}

function get_git {
	test -d .git || return 1

	git_branch=`git branch | grep '*' | cut -d ' ' -f 2`

	return 0
}

function get_project {
	project_name=`basename $PWD`
}


function pythonsh_prompt_update {
	if get_git
	then
		get_pyenv
		get_project
	fi

	export PS1="[${virtual_environment}:${git_branch}] (${project_name}) -> "
}


precmd_functions+=( pythonsh_prompt_update )

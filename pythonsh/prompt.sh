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
    virtual_environment="NA"
  else
    virtual_environment=`echo $environment | cut -d ' ' -f 2`
  fi
}

function get_branch {
  git_branch=`git branch | grep '*' | cut -d ' ' -f 2`

  if git status | grep -i "changes not staged" >/dev/null
  then
    git_flags="*"
  fi

  if git status | grep -i "changes to be committed" >/dev/null
  then
    git_flags="${git_flags}+"
  fi

  if [[ -n $git_flags ]]
  then
    git_branch="${git_branch}(${git_flags})"
  fi
}

function get_project {
  project_name=`basename $PWD`
}

function is_git {
  test -d .git && return 0

  return 1
}

function pythonsh_prompt_update {
  if is_git
  then
    get_pyenv
    get_branch
    get_project

    export PS1="[${virtual_environment}] ${project_name}:${git_branch} -> "
  else
    export PS1="-> "
  fi
}


precmd_functions+=( pythonsh_prompt_update )

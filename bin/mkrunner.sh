#! /usr/bin/env bash

script=`dirname $0`
script="${script}/virtualenv-runner.sh"

ENV=$1

if [[ -z $ENV ]]
then
  ENV='\$1'
fi

shift

if [[ -n $1 ]]
then
  HARDCODE="$*"
else
  HARDCODE=""
fi

sed <$script -e "s,@DEFAULT@,\"$ENV\",g" | sed -e "s,@HARDCODE@,$HARDCODE,g"

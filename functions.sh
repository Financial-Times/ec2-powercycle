#!/bin/bash

# Library of commonly used Bash functions

declare -A SETTINGS

function errorAndExit() {
    echo $1
    exit $2   
}

function exportSettings () {
  for key in "${!SETTINGS[@]}"; do
    export ${key}="${SETTINGS[$key]}"
  done
}

function getKeyValueFromFile () {
  # Looks up value for key in format of key = value or key : value. 
  # Separator can be specified as an argument
  # Expects file to contain key only once
  #
  # arg1 = file name to look up
  # arg2 = key to look up
  # arg3 = key-value separator. Default is '='
  #
  # USAGE
  # keyval=$(getKeyValueFromFile "${HOME}/.aws/credentials" "aws_access_key_id" "=")
  # echo "Value retuned $keyval"

  if [[ -z "$3" ]]; then
    delimiter="="
  else
    delimiter="$3"
  fi
  key=$2

  if [[ -f "$1" ]]; then
    value=$(sed -En "s/(^${key}${delimiter}|${key} ${delimiter} )//p" $1)
    rtncode="$?"
    if [[ "$rtncode" -eq "0" ]]; then      
      echo $value
    fi
  fi
}


function promptUser () {
  echo -ne "\e[31m$1: \e[0m" 
  read var
  SETTINGS[${2}]="${var}"
  if [[ -z "${SETTINGS[${2}]}" ]]; then
    promptUser "${1}" "${2}"
  fi
}

function verifyLambdaFunction () {
  aws lambda get-function --function-name ${SETTINGS[AWS_LAMBDA_FUNCTION]} >/dev/null || errorAndExit "Failed to verify access to Lambda function ${SETTINGS[AWS_LAMBDA_FUNCTION]}" 1
}
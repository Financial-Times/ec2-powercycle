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

function listVersions () {
    newest=$(aws lambda list-versions-by-function --function-name ${SETTINGS[AWS_LAMBDA_FUNCTION]} | grep '"Version"' | grep -v LATEST | cut -d '"' -f 4 | tail -1)
    oldest=$(aws lambda list-versions-by-function --function-name ${SETTINGS[AWS_LAMBDA_FUNCTION]} | grep '"Version"' | grep -v LATEST | cut -d '"' -f 4 | head -1)
    if [[ "${1,,}" == "newest"  && ${newest} -gt ${oldest} ]]; then           
        echo ${newest}
    elif [[ "${1,,}" == "oldest" && ${oldest} -lt ${newest}  ]]; then
        echo ${oldest}
    else 
        unset VERIFIED
        for each in $(aws lambda list-versions-by-function --function-name ec2-powercycle | grep '"Version"' | grep -v LATEST | cut -d '"' -f 4); do 
            if [[ "${each}" -eq "$1" ]]; then
                VERIFIED=0
            fi
        done
        if [[ ! -z "${VERIFIED}" ]]; then
            echo true
        fi
    fi
}

function processCredentials() {

    # Lookup credentials from "${HOME}/.aws/credentials" if not provided as environment variables
    test -z ${AWS_ACCESS_KEY_ID} && AWS_ACCESS_KEY_ID=$(getKeyValueFromFile "${HOME}/.aws/credentials" "aws_access_key_id")
    test -z ${AWS_SECRET_ACCESS_KEY} && AWS_SECRET_ACCESS_KEY=$(getKeyValueFromFile "${HOME}/.aws/credentials" "aws_secret_access_key")
    test -z ${AWS_DEFAULT_REGION} && AWS_DEFAULT_REGION=$(getKeyValueFromFile "${HOME}/.aws/credentials" "region")
    
    # Prompt for credentials if not yet defined
    test -z ${AWS_ACCESS_KEY_ID} && promptUser "Enter AWS_ACCESS_KEY_ID" AWS_ACCESS_KEY_ID || SETTINGS[AWS_ACCESS_KEY_ID]="${AWS_ACCESS_KEY_ID}"
    test -z ${AWS_SECRET_ACCESS_KEY} && promptUser "Enter AWS_SECRET_ACCESS_KEY" AWS_SECRET_ACCESS_KEY || SETTINGS[AWS_SECRET_ACCESS_KEY]="${AWS_SECRET_ACCESS_KEY}"
    test -z ${AWS_DEFAULT_REGION} && promptUser "Enter AWS region" AWS_DEFAULT_REGION || SETTINGS[AWS_DEFAULT_REGION]="${AWS_DEFAULT_REGION}"
    test -z ${AWS_LAMBDA_FUNCTION} && promptUser "Lambda function name" AWS_LAMBDA_FUNCTION || SETTINGS[AWS_LAMBDA_FUNCTION]="${AWS_LAMBDA_FUNCTION}" 
   
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
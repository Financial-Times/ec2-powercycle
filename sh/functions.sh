#!/bin/bash

# Library of commonly used Bash functions

declare -A SETTINGS
declare -A CLI_ARGS

function assumeRole () {
    JSON_OUT='role.json'
    aws sts assume-role --role-arn "${CLI_ARGS[arn]}" --role-session-name "ec2-powercycle" > ${JSON_OUT} || exit 1
    export AWS_ACCESS_KEY_ID="$(getKeyValueFromJSON ${JSON_OUT} AccessKeyId)"
    echo -e "\e[31mAWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID}\e[0m"
    export AWS_SECRET_ACCESS_KEY="$(getKeyValueFromJSON ${JSON_OUT} SecretAccessKey)"
    echo -e "\e[31mAWS_SECRET_ACCESS_KEY: ...not showing for reason because...\e[0m"
    export AWS_SESSION_TOKEN="$(getKeyValueFromJSON ${JSON_OUT} SessionToken)"
    echo -e "\e[31mAWS_SESSION_TOKEN: ${AWS_SESSION_TOKEN}\e[0m"    
}

function createLambdaAlias () {
    aws lambda create-alias --function-name $1 --name $2 --function-version $3 >/dev/null 
}

function errorAndExit() {
    echo $1
    exit $2   
}

function exportSettings () {
  for key in "${!SETTINGS[@]}"; do
    #echo "Exporting ${key}=${SETTINGS[$key]}"
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
    value=$(sed -En "s/(${key}${delimiter}|${key} ${delimiter} )//p" $1)
    rtncode="$?"
    if [[ "$rtncode" -eq "0" ]]; then      
      echo $value
    fi
  fi
}

function getKeyValueFromJSON () {
  # Look up value of key in JSON document.
  # 
  # arg1 = file name to look up
  # arg2 = key to look up
  #
  # USAGE: export AWS_ACCESS_KEY_ID=$(getKeyValueFromJSON role.json AccessKeyId)
  
  key=$2
  if [[ -f "$1" ]]; then
    value=$(sed -En "s/(.${key}.:.)//p" $1)
    rtncode="$?"
    if [[ "$rtncode" -eq "0" ]]; then
        removeJSONmarkup $value
    fi
  fi     
}

function invokeFunction() {
    OUTPUT="lambda-invoke-function.out"
    
    if [[ "${CLI_ARGS[dryrun]}" == "true" ]]; then
        echo "Dryrun on"
        aws lambda invoke  --function-name ${SETTINGS[AWS_LAMBDA_FUNCTION]} --cli-binary-format raw-in-base64-out --payload '{ "DryRun": "True" }' ${OUTPUT}
        RTNCODE="$?"
        return ${RTNCODE}           
    else
        #echo "Invoking function ${SETTINGS[AWS_LAMBDA_FUNCTION]}"  
        aws lambda invoke  --function-name ${SETTINGS[AWS_LAMBDA_FUNCTION]} ${OUTPUT}
        RTNCODE="$?"
        return ${RTNCODE}
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
            echo ${newest}
        fi
    fi
}

function lstrip () {
    # Bash implementation of Python lstrip method
    # Removes white spaces on left hand side of the string
    # arg1 = string
    input=$1
    i=0
    while [ "$i" -lt "${#input}" ]; do
      if [ "${input:$i:1}" != " " ]; then
          echo "${input:$i:${#input}}"
          break
      fi
      (( i++ ))
    done
}

function printArguments() {
    for key in "${!CLI_ARGS[@]}"; do
      echo "${key}=${CLI_ARGS[$key]}"
    done
}

function processArguments () {
    # Process arguments and store them in associative array
    # Odd arguments (1,3,5,etc) become the key
    # Even arguments (2,4,6,etc) become the value
    
    while [[ ${#*} -gt "0" ]]; do
        key=$(echo ${1} | tr -d '-') # Strip the -- prefix from cli argument. --file becomes file
        CLI_ARGS[${key}]="${2}"
        shift && shift || errorAndExit "Odd number of arguments provided. Expecting even numner of key-value pairs, e.g. --key value." 1
    done
}

function processCredentials () {

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

function removeJSONmarkup () {
  # Delete whitespaces, opening/closing quotation marks and comma at the end of string
  # Return string without JSON markup
  input=$1
  length=${#input}
  i=0
  input=$(strip ${input}) # Delete whitespaces
  if [[ "${input:0:1}" == '"' ]]; then # Delete opening quotation if exists
      input="${input:1:`expr ${#input}`}"
  else
      echo "Character \"${input:0:1}\""
  fi
  if [[ "${input:`expr ${#input} - 1`:1}" == ',' ]]; then # Delete trailing comma if exists
      input="${input:0:-1}"
  fi
  if [[ "${input:`expr ${#input} - 1`:1}" == '"' ]]; then # Delete closing quotations if exists
      input="${input:0:-1}"
  fi
  echo "${input}"
}

function rstrip () {
    # Bash implementation of Python rstrip method
    # Removes white spaces on the right hand side of the string
    # arg1 = string
    input=$1
    i=`expr ${#input} - 1`
    while [ "$i" -ge "0" ]; do
      if [ "${input:$i:1}" != " " ]; then
          substring="${input:0:`expr ${i} + 1`}"
          echo "${substring}"
          break
      fi
      (( i-- ))
    done    
}

function strip () {
    # Bash implementation of Python strip method
    # Removes white spaces on the right and left hand side of the string
    # arg1 = string
    input=$(lstrip $1)
    input=$(rstrip $input)
    echo ${input}
}

function verifyLambdaFunction () {
  aws lambda get-function --function-name ${SETTINGS[AWS_LAMBDA_FUNCTION]} >/dev/null || errorAndExit "Failed to verify access to Lambda function ${SETTINGS[AWS_LAMBDA_FUNCTION]}" 1
}

function validateLambdaAlias () {
    aws lambda list-aliases --function-name $1 | grep "Name" | grep $2 >/dev/null
    echo $?
}
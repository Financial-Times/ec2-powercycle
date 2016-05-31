#!/bin/bash

# This script posts EC2-POWERCYCLE package to Lambda

declare -A SETTINGS
PACKAGE="ec2-powercycle.zip"

function errorAndExit () {
  echo -e "\e[31m$1\e[0m"
  exit $2
}

function exportSettings () {
  for key in "${!SETTINGS[@]}"; do
    export ${key}=${SETTINGS[$key]}
  done
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
  aws lambda get-function --function-name ${SETTINGS[AWS_LAMBDA_FUNCTION]} &>/dev/null || errorAndExit "Failed to access Lambda function ${SETTINGS[AWS_LAMBDA_FUNCTION]}. Function must be created before updating." 1
}

function releasePackage () {
  if [[ -f "${1}" ]]; then
    aws lambda update-function-code --function-name ${SETTINGS[AWS_LAMBDA_FUNCTION]} --zip-file fileb://${1} || errorAndExit "Failed to update Lambda function ${SETTINGS[AWS_LAMBDA_FUNCTION]}" 1
  else
    errorAndExit "File ${1} not found" 1
  fi
}

test -z ${AWS_ACCESS_KEY_ID} && promptUser "Enter AWS_ACCESS_KEY_ID" AWS_ACCESS_KEY_ID || SETTINGS[AWS_ACCESS_KEY_ID]="${AWS_ACCESS_KEY_ID}"
test -z ${AWS_SECRET_ACCESS_KEY} && promptUser "Enter AWS_SECRET_ACCESS_KEY" AWS_SECRET_ACCESS_KEY || SETTINGS[AWS_SECRET_ACCESS_KEY]="${AWS_SECRET_ACCESS_KEY}"
test -z ${AWS_DEFAULT_REGION} && promptUser "Enter AWS region for S3 bucket" AWS_DEFAULT_REGION || SETTINGS[AWS_DEFAULT_REGION]="${AWS_DEFAULT_REGION}"
test -z ${AWS_LAMBDA_FUNCTION} && promptUser "Lambda function name" AWS_LAMBDA_FUNCTION || SETTINGS[AWS_LAMBDA_FUNCTION]="${AWS_LAMBDA_FUNCTION}"

echo -e "\e[31mExporting settings\e[0m"
exportSettings
echo -e "\e[31mVerifying Lambda function\e[0m"
verifyLambdaFunction && echo -e "\e[31mLambda function access OK\e[0m"
echo -e "\e[31mUpdate Lambda function\e[0m"
releasePackage ${PACKAGE}
echo -e "\e[31mDone\e[0m"

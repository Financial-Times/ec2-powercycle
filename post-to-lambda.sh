#!/bin/bash

# Post zip package to Lambda
#
# USAGE
# ./post-to-lambda.sh <zip_file>
# <zip_file> defaults to ec2-powercycle.zip

PACKAGE="${1-ec2-powercycle.zip}"

source functions.sh

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

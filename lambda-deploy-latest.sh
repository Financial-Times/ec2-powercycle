#!/bin/bash

# Deploy zip package to Lambda
#
# USAGE
# ./lambda-deploy-latest.sh <zip_file>
# <zip_file> defaults to ec2-powercycle.zip

PACKAGE="${1-ec2-powercycle.zip}"

source "$(dirname $0)/functions.sh"

function releasePackage () {
  if [[ -f "${1}" ]]; then
    aws lambda update-function-code --function-name ${SETTINGS[AWS_LAMBDA_FUNCTION]} --zip-file fileb://${1} || errorAndExit "Failed to update Lambda function ${SETTINGS[AWS_LAMBDA_FUNCTION]}" 1
  else
    errorAndExit "File ${1} not found" 1
  fi
}

processCredentials

echo -e "\e[31mExporting settings\e[0m"
exportSettings
echo -e "\e[31mQuery Lambda function ${SETTINGS[AWS_LAMBDA_FUNCTION]}\e[0m"
verifyLambdaFunction && echo -e "\e[31mLambda function found\e[0m"
echo -e "\e[31mUpdate Lambda function\e[0m"
releasePackage ${PACKAGE}
echo -e "\e[31mDone\e[0m"

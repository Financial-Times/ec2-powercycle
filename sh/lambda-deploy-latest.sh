#!/bin/bash

# Deploy zip package to Lambda
#
# USAGE
# ./lambda-deploy-latest.sh --file ec2-cyclepower.zip --caa true 
# file: path to the zipped lambda
# caa: cross-account access flag, skip processCredentials function
#
# More information: http://docs.aws.amazon.com/cli/latest/reference/lambda/update-function-code.html

source "$(dirname $0)/functions.sh" || exit 1 

function updateFunctionRuntime () {
  if [[ -z "${AWS_LAMBDA_RUNTIME}" ]]; then
    echo -e "\e[31mAWS_LAMBDA_RUNTIME is not set. Skipping Lambda runtime update\e[0m"
    return 0
  fi

  aws lambda update-function-configuration \
    --function-name ${SETTINGS[AWS_LAMBDA_FUNCTION]} \
    --runtime "${AWS_LAMBDA_RUNTIME}" || errorAndExit "Failed to update Lambda function ${SETTINGS[AWS_LAMBDA_FUNCTION]} runtime to ${AWS_LAMBDA_RUNTIME}" 1

  aws lambda wait function-updated \
    --function-name ${SETTINGS[AWS_LAMBDA_FUNCTION]} || errorAndExit "Timed out waiting for Lambda function ${SETTINGS[AWS_LAMBDA_FUNCTION]} runtime update" 1
}

function releasePackage () { 
  if [[ -f "${CLI_ARGS[file]}" ]]; then
    aws lambda update-function-code --function-name ${SETTINGS[AWS_LAMBDA_FUNCTION]} --zip-file fileb://${CLI_ARGS[file]} || errorAndExit "Failed to update Lambda function ${SETTINGS[AWS_LAMBDA_FUNCTION]}" 1
  else
    errorAndExit "File ${CLI_ARGS[file]} not found" 1
  fi
}
echo -e "\e[31mProcess arguments\e[0m"
processArguments ${*}
if [[ "${CLI_ARGS[caa],,} != 'true'}" ]]; then
    echo -e "\e[31mProcess credentials\e[0m"
    processCredentials
    echo -e "\e[31mExporting settings\e[0m"
    exportSettings
else
    echo -e "\e[31mCross account access flag set. Not processing credentials\e[0m"
fi
echo -e "\e[31mQuery Lambda function ${SETTINGS[AWS_LAMBDA_FUNCTION]}\e[0m"
verifyLambdaFunction && echo -e "\e[31mLambda function found\e[0m"
echo -e "\e[31mUpdate Lambda runtime\e[0m"
updateFunctionRuntime
echo -e "\e[31mUpdate Lambda function\e[0m"
releasePackage
echo -e "\e[31mDone\e[0m"

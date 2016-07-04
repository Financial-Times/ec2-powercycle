#!/bin/bash

# Script executes Lambda function 
#
# USAGE:
# ./lambda-invoke-function.sh

source functions.sh

function invokeFunction() {
    aws lambda invoke  --function-name ${SETTINGS[AWS_LAMBDA_FUNCTION]}
}

if [[ "$1" == "DryRun" ]]; then
    echo -e "\e[31mINvoking function ${SETTINGS[AWS_LAMBDA_FUNCTION]} in DryRun mode. Exit 0.\e[0m"
    exit 0
fi

test -z ${AWS_ACCESS_KEY_ID} && promptUser "Enter AWS_ACCESS_KEY_ID" AWS_ACCESS_KEY_ID || SETTINGS[AWS_ACCESS_KEY_ID]="${AWS_ACCESS_KEY_ID}"
test -z ${AWS_SECRET_ACCESS_KEY} && promptUser "Enter AWS_SECRET_ACCESS_KEY" AWS_SECRET_ACCESS_KEY || SETTINGS[AWS_SECRET_ACCESS_KEY]="${AWS_SECRET_ACCESS_KEY}"
test -z ${AWS_DEFAULT_REGION} && promptUser "Enter AWS region" AWS_DEFAULT_REGION || SETTINGS[AWS_DEFAULT_REGION]="${AWS_DEFAULT_REGION}"
test -z ${AWS_LAMBDA_FUNCTION} && promptUser "Lambda function name" AWS_LAMBDA_FUNCTION || SETTINGS[AWS_LAMBDA_FUNCTION]="${AWS_LAMBDA_FUNCTION}"

echo -e "\e[31mExporting settings\e[0m"
exportSettings
echo -e "\e[31mVerifying Lambda function\e[0m"
verifyLambdaFunction && echo -e "\e[31mLambda function access OK\e[0m" || errorAndExit "Failed to access function ${SETTINGS[AWS_LAMBDA_FUNCTION]}" 1
invokeFunction && echo -e "\e[31mLambda function ${SETTINGS[AWS_LAMBDA_FUNCTION]} executed successfully\e[0m" || errorAndExit "Failed to run Lambda function ${SETTINGS[AWS_LAMBDA_FUNCTION]}" 1
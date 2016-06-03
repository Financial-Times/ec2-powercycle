#!/bin/bash

# Script creates a new version of the $LATEST Lambda job
# Lambda alias can then be linked to specific version 
# More information: http://docs.aws.amazon.com/cli/latest/reference/lambda/publish-version.html
#
# USAGE:
# ./lambda-publish-version.sh

source functions.sh

function publishVersion() {
    aws lambda publish-version  --function-name ${SETTINGS[AWS_LAMBDA_FUNCTION]}
}

test -z ${AWS_ACCESS_KEY_ID} && promptUser "Enter AWS_ACCESS_KEY_ID" AWS_ACCESS_KEY_ID || SETTINGS[AWS_ACCESS_KEY_ID]="${AWS_ACCESS_KEY_ID}"
test -z ${AWS_SECRET_ACCESS_KEY} && promptUser "Enter AWS_SECRET_ACCESS_KEY" AWS_SECRET_ACCESS_KEY || SETTINGS[AWS_SECRET_ACCESS_KEY]="${AWS_SECRET_ACCESS_KEY}"
test -z ${AWS_DEFAULT_REGION} && promptUser "Enter AWS region" AWS_DEFAULT_REGION || SETTINGS[AWS_DEFAULT_REGION]="${AWS_DEFAULT_REGION}"
test -z ${AWS_LAMBDA_FUNCTION} && promptUser "Lambda function name" AWS_LAMBDA_FUNCTION || SETTINGS[AWS_LAMBDA_FUNCTION]="${AWS_LAMBDA_FUNCTION}"

echo -e "\e[31mExporting settings\e[0m"
exportSettings
echo -e "\e[31mVerifying Lambda function\e[0m"
verifyLambdaFunction && echo -e "\e[31mLambda function access OK\e[0m" || errorAndExit "Failed to access function ${SETTINGS[AWS_LAMBDA_FUNCTION]}" 1
publishVersion && echo -e "\e[31mNew version created successfully\e[0m" || errorAndExit "Failed to create new version for ${SETTINGS[AWS_LAMBDA_FUNCTION]}" 1
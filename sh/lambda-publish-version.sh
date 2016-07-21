#!/bin/bash

# Script creates a new version of the $LATEST Lambda job
# Lambda alias can then be linked to specific version 
# More information: http://docs.aws.amazon.com/cli/latest/reference/lambda/publish-version.html
#
# USAGE:
# ./lambda-publish-version.sh --function function_name

source "$(dirname $0)/functions.sh" || exit 1

function publishVersion() {
    aws lambda publish-version  --function-name ${SETTINGS[AWS_LAMBDA_FUNCTION]}
}

if [[ ! -z "${CLI_ARGS[--function]}" ]]; then
    AWS_LAMBDA_FUNCTION="${CLI_ARGS[--function]}"
fi

echo -e "\e[31mProcessing arguments\e[0m"
processArguments ${*}
if [[ "${CLI_ARGS[caa],,} != 'true'}" ]]; then
    echo -e "\e[31mProcessing credentials\e[0m"
    processCredentials
    echo -e "\e[31mExporting settings\e[0m"
    exportSettings
else
    echo -e "\e[31mCross account access flag set. Not processing credentials\e[0m"    
fi
echo -e "\e[31mVerifying Lambda function\e[0m"
verifyLambdaFunction && echo -e "\e[31mLambda function access OK\e[0m" || errorAndExit "Failed to access function ${SETTINGS[AWS_LAMBDA_FUNCTION]}" 1
publishVersion && echo -e "\e[31mNew version created successfully\e[0m" || errorAndExit "Failed to create new version for ${SETTINGS[AWS_LAMBDA_FUNCTION]}" 1
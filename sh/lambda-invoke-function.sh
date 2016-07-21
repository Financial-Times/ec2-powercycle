#!/bin/bash

# Script executes Lambda function 
#
# USAGE:
# ./lambda-invoke-function.sh --function function_name [--dryrun true] [--caa true]
# More information: http://docs.aws.amazon.com/cli/latest/reference/lambda/invoke.html

source "$(dirname $0)/functions.sh" || exit 1

processArguments ${*}

if [[ "${CLI_ARGS[caa],,} != 'true'}" ]]; then
    processCredentials
    echo -e "\e[31mExporting settings\e[0m"
    exportSettings
else
    echo -e "\e[31mCross account access flag set. Not processing credentials\e[0m"
fi

echo -e "\e[31mVerifying Lambda function\e[0m"
verifyLambdaFunction && echo -e "\e[31mLambda function access OK\e[0m" || errorAndExit "Failed to access function ${SETTINGS[AWS_LAMBDA_FUNCTION]}"
invokeFunction && echo -e "\e[31mLambda function ${SETTINGS[AWS_LAMBDA_FUNCTION]} executed successfully\e[0m" || errorAndExit "Failed to run Lambda function ${SETTINGS[AWS_LAMBDA_FUNCTION]}" 1
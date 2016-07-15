#!/bin/bash

# Script executes Lambda function 
#
# USAGE:
# ./lambda-invoke-function.sh <function_name> [DryRun]
# More information: http://docs.aws.amazon.com/cli/latest/reference/lambda/invoke.html

OUTPUT="lambda-invoke-function.out"

source "$(dirname $0)/functions.sh" || exit 1

function invokeFunction() {
    if [[ "${SETTINGS[AWS_LAMBDA_DRYRUN]}" ]]; then
        aws lambda invoke  --function-name ${SETTINGS[AWS_LAMBDA_FUNCTION]} --payload '{ "DryRun": "True" }' ${OUTPUT}
        RTNCODE="$?"
        return ${RTNCODE}           
    else        
        aws lambda invoke  --function-name ${SETTINGS[AWS_LAMBDA_FUNCTION]} ${OUTPUT}
        RTNCODE="$?"
        return ${RTNCODE}
    fi
}

if [[ ! -z "$1" ]]; then
    AWS_LAMBDA_FUNCTION="$1"
fi

if [[ "$2" == "DryRun" ]]; then
    SETTINGS[AWS_LAMBDA_DRYRUN]="0"
    echo -e "\e[31mInvoke function ${SETTINGS[AWS_LAMBDA_FUNCTION]} in DryRun mode.\e[0m"
fi

processCredentials

echo -e "\e[31mExporting settings\e[0m"
exportSettings
echo -e "\e[31mVerifying Lambda function\e[0m"
verifyLambdaFunction && echo -e "\e[31mLambda function access OK\e[0m" || errorAndExit "Failed to access function ${SETTINGS[AWS_LAMBDA_FUNCTION]}" 1
invokeFunction && echo -e "\e[31mLambda function ${SETTINGS[AWS_LAMBDA_FUNCTION]} executed successfully\e[0m" || errorAndExit "Failed to run Lambda function ${SETTINGS[AWS_LAMBDA_FUNCTION]}" 1
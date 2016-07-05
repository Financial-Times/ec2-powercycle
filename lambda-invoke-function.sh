#!/bin/bash

# Script executes Lambda function 
#
# USAGE:
# ./lambda-invoke-function.sh <function_name> [DryRun]
# More information: http://docs.aws.amazon.com/cli/latest/reference/lambda/invoke.html

OUTPUT="lambda-invoke-function.out"

source functions.sh

function invokeFunction() {
    if [[ "${SETTINGS[AWS_LAMBDA_DRYRUN]}" ]]; then
        aws lambda invoke  --function-name ${SETTINGS[AWS_LAMBDA_FUNCTION]} --payload '{ "DryRun": "True" }' ${OUTPUT}
        RTNCODE="$?"
        if [[ -f ${OUTPUT} ]]; then
            echo -e "\e[31mInvoke function returned: \e[0m"
            cat ${OUTPUT}
        else
            echo -e "\e[31mOutput file ${OUTPUT} not found!\e[0m"
        fi
        return ${RTNCODE}           
    else        
        aws lambda invoke  --function-name ${SETTINGS[AWS_LAMBDA_FUNCTION]} ${OUTPUT}
        RTNCODE="$?"
        if [[ -f ${OUTPUT} ]]; then
            echo -e "\e[31mInvoke function returned: \e[0m"
            cat ${OUTPUT}
        else
            echo -e "\e[31mOutput file ${OUTPUT} not found!\e[0m"
        fi       
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

# Lookup credentials from "${HOME}/.aws/credentials" if not provided as environment variables
test -z ${AWS_ACCESS_KEY_ID} && AWS_ACCESS_KEY_ID=$(getKeyValueFromFile "${HOME}/.aws/credentials" "aws_access_key_id")
test -z ${AWS_SECRET_ACCESS_KEY} && AWS_SECRET_ACCESS_KEY=$(getKeyValueFromFile "${HOME}/.aws/credentials" "aws_secret_access_key")
test -z ${AWS_DEFAULT_REGION} && AWS_DEFAULT_REGION=$(getKeyValueFromFile "${HOME}/.aws/credentials" "region")

test -z ${AWS_ACCESS_KEY_ID} && promptUser "Enter AWS_ACCESS_KEY_ID" AWS_ACCESS_KEY_ID || SETTINGS[AWS_ACCESS_KEY_ID]="${AWS_ACCESS_KEY_ID}"
test -z ${AWS_SECRET_ACCESS_KEY} && promptUser "Enter AWS_SECRET_ACCESS_KEY" AWS_SECRET_ACCESS_KEY || SETTINGS[AWS_SECRET_ACCESS_KEY]="${AWS_SECRET_ACCESS_KEY}"
test -z ${AWS_DEFAULT_REGION} && promptUser "Enter AWS region" AWS_DEFAULT_REGION || SETTINGS[AWS_DEFAULT_REGION]="${AWS_DEFAULT_REGION}"
test -z ${AWS_LAMBDA_FUNCTION} && promptUser "Lambda function name" AWS_LAMBDA_FUNCTION || SETTINGS[AWS_LAMBDA_FUNCTION]="${AWS_LAMBDA_FUNCTION}"

echo -e "\e[31mExporting settings\e[0m"
exportSettings
echo -e "\e[31mVerifying Lambda function\e[0m"
verifyLambdaFunction && echo -e "\e[31mLambda function access OK\e[0m" || errorAndExit "Failed to access function ${SETTINGS[AWS_LAMBDA_FUNCTION]}" 1
invokeFunction && echo -e "\e[31mLambda function ${SETTINGS[AWS_LAMBDA_FUNCTION]} executed successfully\e[0m" || errorAndExit "Failed to run Lambda function ${SETTINGS[AWS_LAMBDA_FUNCTION]}" 1
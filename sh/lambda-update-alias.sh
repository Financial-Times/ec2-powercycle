#!/bin/bash

# Query or validate versions of Lambda functions.
# This script excluded version $LATEST from the query. Only versions with proper version number are queried.
#  
# USAGE
# ./lambda-update-alias --function function_name --alias alias_name --version version number
# If version number is omitted then script will look up the latest version number
#
# More information: http://docs.aws.amazon.com/cli/latest/reference/lambda/update-alias.html

source "$(dirname $0)/functions.sh" || exit 1

function updateAlias () {
    aws lambda update-alias --function-name $1 --name $2 --function-version $3
}


processArguments ${*}

if [[ ! -z "${CLI_ARGS[function]}" ]]; then
    AWS_LAMBDA_FUNCTION="${CLI_ARGS[function]}"
fi

if [[ ! -z "${CLI_ARGS[alias]}" ]]; then
    AWS_LAMBDA_ALIAS="${CLI_ARGS[alias]}"
fi

if [[ "${CLI_ARGS[caa],,} != 'true'}" ]]; then
    processCredentials
    echo -e "\e[31mExporting settings\e[0m"
    exportSettings
else
    echo -e "\e[31mCross account access flag set. Not processing credentials\e[0m"
fi
echo -e "\e[31mQuery Lambda function ${SETTINGS[AWS_LAMBDA_FUNCTION]}\e[0m"
verifyLambdaFunction && echo -e "\e[31mLambda function found\e[0m"

if [[ -z "${CLI_ARGS[version]}" || "${CLI_ARGS[version]}" == "newest" ]]; then # Look up most recent version
    version=$(listVersions "newest")
    if [[ -z ${version} ]]; then 
        errorAndExit "Failed to get latest version" 1
    fi

else # check whether version exists
    version_found=$(listVersions "${CLI_ARGS[--version]}")
    if [[ -z "${version_found}" ]]; then
        errorAndExit "Version ${3} not found" 1
    else
        echo -e "\e[31mVersion $3 found\e[0m"
        version=${CLI_ARGS[version]}
    fi
         
fi

if [[ "$(validateLambdaAlias ${SETTINGS[AWS_LAMBDA_FUNCTION]} ${AWS_LAMBDA_ALIAS})" -eq "1" ]]; then # Create alias if it doesn't exist
    echo -e "\e[31mCreating alias ${AWS_LAMBDA_ALIAS} and pointing to version ${version}\e[0m"
    createLambdaAlias ${SETTINGS[AWS_LAMBDA_FUNCTION]} ${AWS_LAMBDA_ALIAS} ${version} || errorAndExit "Failed to create alias  ${AWS_LAMBDA_ALIAS}" 1
else
    echo -e "\e[31mUpdating alias\e[0m"
    updateAlias ${SETTINGS[AWS_LAMBDA_FUNCTION]} ${AWS_LAMBDA_ALIAS} ${version}
fi

echo -e "\e[31mDone\e[0m"

#!/bin/bash

# Query or validate versions of Lambda functions.
# This script excluded version $LATEST from the query. Only versions with proper version number are queried.
#  
# USAGE
# ./lambda-update-alias <function_name> <alias_name> [version number]
# If version number is omitted then script will look up the latest version number


source "$(dirname $0)/functions.sh" || exit 1

function updateAlias () {
    aws lambda update-alias --function-name $1 --name $2 --function-version $3
}


if [[ ! -z "$1" ]]; then
    AWS_LAMBDA_FUNCTION="$1"
fi

if [[ ! -z "$2" ]]; then
    AWS_LAMBDA_ALIAS="$2"
fi

processCredentials

echo -e "\e[31mExporting settings\e[0m"
exportSettings
echo -e "\e[31mQuery Lambda function ${SETTINGS[AWS_LAMBDA_FUNCTION]}\e[0m"
verifyLambdaFunction && echo -e "\e[31mLambda function found\e[0m"

if [[ -z "$3" || "${3,,}" == "newest" ]]; then # Look up most recent version
    version=$(listVersions "newest")
    if [[ -z ${version} ]]; then 
        errorAndExit "Failed to get latest version" 1
    fi

else # check whether version exists
    version=$(listVersions "$3")
    if [[ -z "${version}" ]]; then
        errorAndExit "Version ${3} not found" 1
    else
        echo -e "\e[31mVersion $3 found\e[0m"
        version=$3
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

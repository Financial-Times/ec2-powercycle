#!/bin/bash
#
# Switch role for cross-account access
# More info: http://docs.aws.amazon.com/IAM/latest/UserGuide/tutorial_cross-account-with-roles.html
#
# USAGE
# ./iam-assume-role.sh --arn role_arn [--mock true]
# 
# ARGUMENTS
# --arn: A string like arn:aws:iam::371548805176:role/circleci-to-ec2powercycle-lambda.infraprod-to-infradev
# --mock: If set true then do not attempt to connect to AWS API

source "$(dirname $0)/functions.sh" || exit 1 

function assumeRole () {
    aws sts assume-role --role-arn "${CLI_ARGS[--arn]}" --role-session-name "ec2-powercycle"  || exit 1 
}

JSON_OUT='role.json'
ARG1=$1
MOCK=$2
test -z ${ARG1} && errorAndExit "Usage: $(dirname $0)/iam-assume-role.sh --arn <role_arn> [--mock true]" 1 

processArguments ${*}
processCredentials
echo -e "\e[31mExporting settings\e[0m"
exportSettings

echo -e "\e[31mGetting temporary cross-account access credentials\e[0m"
if [[ "${CLI_ARGS[--mock],,}" != 'true' ]]; then # Only assume role if --mock is not true
    assumeRole > ${JSON_OUT}
else
    echo -e "\e[31m...except I am not because --mock is set true\e[0m"
fi

export AWS_ACCESS_KEY_ID="$(getKeyValueFromJSON ${JSON_OUT} AccessKeyId)"
echo -e "\e[31mAWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID}\e[0m"
export AWS_SECRET_ACCESS_KEY="$(getKeyValueFromJSON ${JSON_OUT} SecretAccessKey)"
echo -e "\e[31mAWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY}\e[0m"
export AWS_SESSION_TOKEN="$(getKeyValueFromJSON ${JSON_OUT} SessionToken)"
echo -e "\e[31mAWS_SESSION_TOKEN: ${AWS_SESSION_TOKEN}\e[0m"

verifyLambdaFunction
#invokeFunction
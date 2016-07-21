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

if [[ -n "${AWS_CROSS_ACCCOUNT_ACCESS_ARN}" ]]; then
    # Set CLI_ARGS[arn] if present
    # This must be set before processArguments function call to enable
    # CLI_ARGS[arn] value to be overriden by command line argument --arn
    CLI_ARGS[arn]="${AWS_CROSS_ACCCOUNT_ACCESS_ARN}"    
fi
    
processArguments ${*}
test -z ${CLI_ARGS[arn]} && errorAndExit "Usage: $(dirname $0)/iam-assume-role.sh --arn <role_arn> [--mock true]" 0
processCredentials
echo -e "\e[31mExporting settings\e[0m"
exportSettings

echo -e "\e[31mGetting temporary cross-account access credentials\e[0m"
if [[ "${CLI_ARGS[mock],,}" != 'true' ]]; then # Only assume role if --mock is not true
    assumeRole 
else
    echo -e "\e[31m...except I am not because --mock is set true\e[0m"
fi

verifyLambdaFunction && echo -e "\e[31mLambda function access OK\e[0m" || errorAndExit "Failed to access function ${SETTINGS[AWS_LAMBDA_FUNCTION]}" 1
. $(dirname $0)/lambda-deploy-latest.sh --file ec2-powercycle.zip --caa true 
. $(dirname $0)/lambda-invoke-function.sh --function ec2-powercycle --caa true --dryrun true
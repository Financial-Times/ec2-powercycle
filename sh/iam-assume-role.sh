#!/bin/bash
#
# Switch role for cross-account access
# More info: http://docs.aws.amazon.com/IAM/latest/UserGuide/tutorial_cross-account-with-roles.html
#
# USAGE
# ./iam-assume-role.sh <role_arn>
# 

source "$(dirname $0)/functions.sh" || exit 1 

function assumeRole () {
    aws sts assume-role --role-arn "arn:aws:iam::371548805176:role/circleci-to-ec2powercycle-lambda.infraprod-to-infradev" --role-session-name "Jussi"    
}

arg1=$1

test -z ${arg1} && errorAndExit "Usage: ./iam-assume-role.sh <role_arn>" 1 

echo "Got argument $1"
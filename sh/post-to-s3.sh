#!/bin/bash

# This script posts EC2-POWERCYCLE package to S3

PACKAGE="ec2-powercycle.zip"

source functions.sh
    
function listBucket () {
  aws s3 ls s3://${SETTINGS[AWS_S3_BUCKET]} || errorAndExit "Failed to access bucket s3://${SETTINGS[AWS_S3_BUCKET]}" 1
}

function uploadPackage () {
  if [[ -f "${1}" ]]; then
    aws s3 cp $1 s3://${SETTINGS[AWS_S3_BUCKET]}
  else
    errorAndExit "File ${1} not found" 1
  fi
}

test -z ${AWS_ACCESS_KEY_ID} && promptUser "Enter AWS_ACCESS_KEY_ID" AWS_ACCESS_KEY_ID || SETTINGS[AWS_ACCESS_KEY_ID]="${AWS_ACCESS_KEY_ID}"
test -z ${AWS_SECRET_ACCESS_KEY} && promptUser "Enter AWS_SECRET_ACCESS_KEY" AWS_SECRET_ACCESS_KEY || SETTINGS[AWS_SECRET_ACCESS_KEY]="${AWS_SECRET_ACCESS_KEY}"
test -z ${AWS_DEFAULT_REGION} && promptUser "Enter AWS region for S3 bucket" AWS_DEFAULT_REGION || SETTINGS[AWS_DEFAULT_REGION]="${AWS_DEFAULT_REGION}"
test -z ${AWS_S3_BUCKET} && promptUser "Enter S3 bucket ID" AWS_S3_BUCKET || SETTINGS[AWS_S3_BUCKET]="${AWS_S3_BUCKET}"

echo -e "\e[31mExporting settings\e[0m"
exportSettings
echo -e "\e[31mTesting bucket access\e[0m"
listBucket && echo -e "\e[31mBucket access OK\e[0m"
echo -e "\e[31mUploading package\e[0m"
uploadPackage ${PACKAGE}
echo -e "\e[31mListing bucket content\e[0m"
listBucket

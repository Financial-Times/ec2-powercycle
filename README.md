# EC2-POWERCYCLE

_AWS Lambda function to stop and start EC2 instances based on resource tag using crontab-like expressions_


### Table of Contents
**[Creating resource tag](#creating-resource-tag)**  
**[Creating a Lambda Deployment Package](#creating-a-lambda-deployment-package)**  
**[Build environment](#build-environment)**  
**[IAM policy](#iam-policy)**  
**[Setting up Lambda function](#setting-up-lambda-function)**  


## Creating resource tag

Lambda function looks for EC2 instances that has resource tag _ec2Powewrcycle_ attached to it.

Tag value is simple JSON document that describes start and stop schedule in [crontab-like expressions](http://en.wikipedia.org/wiki/Cron).

### Example stop/start schedule: Mon - Fri, 8.45am - 5.40pm
```
ec2Powercycle: { "start": "45 8 * * 1-5", "stop": "40 17 * * 1-5" }
```
#### NOTE

Stopping instances on an hour's mark may result in extra hour to be charged. 
To fully utilise instance hours stop/start schdeule should be set 5 minutes prior to hour's mark.

__BAD EXAMPLE__

Scheduling instances to stop on an hour (runtime 8 hours): 

```
ec2Powercycle: { "start": "0 9 * * 1-5", "stop": "0 17 * * 1-5" }
```

__GOOD EXAMPLE__

Scheduling instances to stop 5 minutes before the hour (runtime 7 hours 55 minutes): 

```
ec2Powercycle: { "start": "0 9 * * 1-5", "stop": "55 16 * * 1-5" }
```

## Creating a Lambda Deployment Package

EC2-POWERCYCLE uses 3rd party library called [Croniter](https://github.com/kiorky/croniter) which must be installed before deployment package is created.

### Installing Croniter into lib/ directory

```
pip install croniter -t lib/
```

### Creating zip archive

The following command is run in the root of the ec2-powercycle repository.
The command bundles ec2-powercycle business logic, its dependencies and the README.md which can be uploaded to Lambda or S3 bucket.   

```
zip -r ../ec2-powercycle-0.0.1.zip ./*.py lib/ README.md
```

## Build environment

This repository ships with [Dockerfile](https://github.com/Financial-Times/ec2-powercycle/blob/master/Dockerfile) that can be used for packaging and deployment automation. 

### Building Docker image

The following command is run in the root of the repository and it creates a Docker container called ec2-powercycle with tag value 1.
```
 sudo docker build -t ec2powercycle .
```

### Launching Docker image

When Docker image is running it first executes the packaging script [package.sh](https://github.com/Financial-Times/ec2-powercycle/blob/master/package.sh), then deployment script [push-to-s3.sh](https://github.com/Financial-Times/ec2-powercycle/blob/master/post-to-s3.sh) that uploads ec2-powercycle.zip package into S3 bucket.

To run [push-to-s3.sh](https://github.com/Financial-Times/ec2-powercycle/blob/master/post-to-s3.sh) in __headless__ mode you can provide AWS credentials as Docker environment variables.

```
sudo docker run --env "AWS_ACCESS_KEY_ID=<access_key_id>" \
--env "AWS_SECRET_ACCESS_KEY=<access_key_secret>" \
--env "AWS_DEFAULT_REGION=<aws_region_for_s3_bucket>" \
--env "AWS_S3_BUCKET=<s3_bucket_name>" \
-it ec2powercycle
```

Launching Docker image without environment variable will run [push-to-s3.sh](https://github.com/Financial-Times/ec2-powercycle/blob/master/post-to-s3.sh) in interactive mode that prompts user for AWS credentials. 
```
sudo docker run -it ec2-powercycle:1
```


## IAM policy

When creating Lambda function you will be asked to associate IAM role with the function.

### Creating Identity and Access Management (IAM) policy for Lambda function
  
The following policy example enables Lambda function to access the following AWS services:

  * __CloudWatch__ - Full access to Amazon CloudWatch for logging and job scheduling
  * __EC2__ - Access to query status and stop/start instances when resource tag ec2Powercycle is attached to the instance and environment tag does not equal __p__ (p=production)
  
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:::*"
        },
        {
            "Effect": "Allow",
            "Action": "ec2:Describe*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:StartInstances",
                "ec2:StopInstances"
            ],
            "Condition": {
                "StringLike": {
                    "ec2:ResourceTag/ec2Powercycle": "*"
                },
                "StringNotEqualsIgnoreCase": {
                    "ec2:ResourceTag/environment": "p"
                }
            },
            "Resource": "arn:aws:ec2:*:*:instance/*"
        }
    ]
}
```

## Setting up Lambda function

Once deployment package is in S3 bucket we can create a Lambda function and use CloudWatch to set the function to run periodically. 

### Creating Lambda function

 1. Log on to AWS console and go to Lambda configuration menu
 2. Click _Create a Lambda function_ 
 3. In _Select blueprint_ menu click _Skip_ button
 4. on _Configure function_ page provide the following details
 * Name*: Name of the Lambda function
 * Description: Optional description of the function
 * Runtime*: Python 2.7
 5. In _Lambda function code_ section select _Upload a file from Amazon S3_
 6. Paste the deployment package URL into field _S3 link URL_
 * _S3 link URL_ can be found from Properties of ec2powercycle.zip package in S3 bucket
 7. In _Lambda function handler and role_ section set handler name _ec2_powercycle.handler_
 8. Select the role that has the above IAM policy attached to it
 9. Click _Next_ and _Creat function_
  
### Scheduling Lambda function

 1. In Lambda configuration menu opne the ec2Ppowermanage Lambda job
 2. Go to _Event sources_ tab
 3. Click _Add event source_
 4. Select _Event source type:_ __CloudWatchEvents - Schedule__ and provide the following details
 * _Rule name:_ __whatever unique name__
 * _Rule description:_ __optional description of the rule__
 * _Schedule expression:_ __rate(15 minutes)__
 5. Click _Submit_ to create schedule



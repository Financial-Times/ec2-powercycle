# EC2-POWERCYCLE

_AWS Lambda function to stop and start EC2 instances based on resource tag using crontab-like expressions_


### Table of Contents
**[Usage](#usage)**  
**[Testing and development](#testing-and-development)**  
**[Creating a Lambda Deployment Package](#creating-a-lambda-deployment-package)**  
**[Build environment](#build-environment)**  
**[Identity and Access Management policy](#identity-and-access-management-policy)**  
**[Setting up Lambda function](#setting-up-lambda-function)**   


## Usage

Lambda function looks for EC2 instances that has a resource tag _ec2Powewrcycle_ attached to it.

Tag value is simple JSON document that describes start and stop schedule in [crontab-like expressions](http://en.wikipedia.org/wiki/Cron).

### Example stop/start schedule: Mon - Fri, 8.00am - 5.55pm
```
ec2Powercycle: { "start": "0 8 * * 1-5", "stop": "55 17 * * 1-5" }
```

As of [commit 00389de](https://github.com/Financial-Times/ec2-powercycle/commit/00389defafe30d1a85627a35713640a6e150e7e7) the stop/start schedule can be defined as an URL to publicly accessible JSON document. This feature can be handy when managing schedule for large number of nodes.
```
ec2Powercycle: https://raw.githubusercontent.com/Financial-Times/ec2-powercycle/master/json/dev-schedule.json
```



## Testing and development

To run ec2Powercycle job local dev environment you need to install all dependencies such as boto3 and croniter. 
Full list of dependencies can be found in the file [ec2_powercycle.py](https://github.com/Financial-Times/ec2-powercycle/blob/master/ec2_powercycle.py)

You also need to set up AWS credetials (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_DEFAULT_REGION) in order to interact with AWS API.

To run the job first change to _python_ directory inside the repository, then call the hander() function.

```
cd /path/to/repository
python -c "from ec2_powercycle import * ; handler()"
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

When Docker image is running it first executes the packaging script [package.sh](https://github.com/Financial-Times/ec2-powercycle/blob/master/package.sh), then deployment script [post-to-lambda.sh](https://github.com/Financial-Times/ec2-powercycle/blob/master/post-to-lambda.sh) that pushes ec2-powercycle.zip package into Lambda.

To run [post-to-lambda.sh](https://github.com/Financial-Times/ec2-powercycle/blob/master/post-to-lambda.sh) in __headless__ mode you can provide AWS credentials as Docker environment variables.

```
sudo docker run --env "AWS_ACCESS_KEY_ID=<access_key_id>" \
--env "AWS_SECRET_ACCESS_KEY=<access_key_secret>" \
--env "AWS_DEFAULT_REGION=<aws_region_for_s3_bucket>" \
--env "AWS_LAMBDA_FUNCTION=<lambda_function_name>" \
-it ec2powercycle
```

Launching Docker image without environment variable will run [post-to-lambda.sh](https://github.com/Financial-Times/ec2-powercycle/blob/master/post-to-lambda.sh) in interactive mode that prompts user for AWS credentials. 
```
sudo docker run -it ec2-powercycle
```

## Serverless build pipeline


[Circleci](https://circleci.com) is a hosted CI service that integrates nicely with [Github](https://github.com) and [AWS](http://console.aws.amazon.com/).

### Adding AWS credentials to Circleci

To enable Circleci build job to deploy deployment package to Lambda the build job must be configured with AWS credentials.

 * Go to [Circleci Dashboad](https://circleci.com/dashboard) and click the cog icon associated with build job
 * Under the _Permissions_ category click _AWS Permissions_
 * Fill out _Access Key ID_ and _Secret Access Key_ fields


## Identity and Access Management policy

When creating Lambda function you will be asked to associate IAM role with the function.

### IAM policy for Lambda function
  
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
                "logs:PutLogEvents",
                 "logs:DescribeLogStreams"
            ],
            "Resource": "arn:aws:logs:*:*:*"
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

### IAM policy for build pipeline

The following policy enables build and deployment job to update Lambda function, invoke it and update aliases.

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "lambda:CreateAlias",
                "lambda:GetFunction",
                "lambda:InvokeFunction",
                "lambda:List*",
                "lambda:PublishVersion",
                "lambda:UpdateAlias",
                "lambda:UpdateFunctionCode"
            ],
            "Resource": [
                "arn:aws:lambda:*:*:function:ec2-powercycle"
            ]
        }
    ]
}
```


## Creating Lambda function

Once deployment package has been created we can create a Lambda function and use CloudWatch to set the function to run periodically. 

### Creating Lambda function

 1. Log on to AWS console and go to Lambda configuration menu
 2. Click _Create a Lambda function_ 
 3. In _Select blueprint_ menu choose one of the blueprints (e.g. _s3-get-object-python_) click _Remove_ button on the next screen to remove _triggers_. Then click _Next_.
 4. on _Configure function_ page provide the following details
 * Name*: Name of the Lambda function
 * Description: Optional description of the function
 * Runtime*: Python 2.7
 5. In _Lambda function code_ section select _Upload a .ZIP file_ to upload ec2powercycle.zip package to Lambda
 6. In _Lambda function handler and role_ section set handler name _ec2_powercycle.handler_
 7. Select the role that has the above IAM policy attached to it
 8. Click _Next_ and _Create function_
  
### Scheduling Lambda function

 1. In Lambda configuration menu opne the ec2Ppowermanage Lambda job
 2. Go to _Event sources_ tab
 3. Click _Add event source_
 4. Select _Event source type:_ __CloudWatchEvents - Schedule__ and provide the following details
 * _Rule name:_ __whatever unique name__
 * _Rule description:_ __optional description of the rule__
 * _Schedule expression:_ __rate(15 minutes)__
 5. Click _Submit_ to create schedule
 
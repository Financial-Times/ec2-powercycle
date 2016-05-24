# EC2-POWERCYCLE

_AWS Lambda function to stop and start EC2 instances based on resource tag_

## Usage

## Creating resource tag

Lambda function looks for EC2 instances that has resource tag _businessHours_ attached to it.

Tag value is simple JSON document that describes start and stop schedule in [crontab-like expressions](http://en.wikipedia.org/wiki/Cron).

### Example stop/start schedule: Mon - Fri, 8.45am - 5.40pm
```
businessHours: { "start": "45 8 * * 1-5", "stop": "40 17 * * 1-5" }
```
NOTE: Stopping instances on an hour's mark may result in extra hour to be charged. 
To fully utilise instance hours stop/start schdeule should be set 5 minutes prior to hour's mark.
For example instead of setting schedule  _businessHours: { "start": "0 9 * * 1-5", "stop": "0 17 * * 1-5" }_ 
set it to stop instance 5 minutes earlier _businessHours: { "start": "45 8 * * 1-5", "stop": "40 17 * * 1-5" }_
  

## Creating a Lambda Deployment Package

EC2-POWERCYCLE uses 3rd party library called [Croniter](https://github.com/kiorky/croniter) which must be installed before deployment package is created.

### Installing Croniter into lib/ directory

```
pip install croniter -t lib/
```

### Creating zip archive

```
zip -r ../ec2-powercycle-0.0.1.zip ./*.py lib/ README.md
```


# EC2-POWERCYCLE

_AWS Lambda function to stop and start EC2 instances based on resource tag_

## Usage

## Creating resource tag

Lambda function looks for EC2 instances that has resource tag _businessHours_ attached to it.

Tag value is simpel JSON document that describes start and stop time in [crontab-like expressions](http://en.wikipedia.org/wiki/Cron).

### Example stop/start schedule: Mon - Fri, 8am - 5pm
```
businessHours: { "stop": "0 17 * * 1-5", "start": "0 8 * * 1-5" }
```

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


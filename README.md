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



And here's some code!

```javascript
$(function(){
  $('div').html('I am a div.');
});
```
```
### test
Warning
```
### Warning
This is [on GitHub](https://github.com/jbt/markdown-editor) so let me know if I've b0rked it somewhere.


Props to Mr. Doob and his [code editor](http://mrdoob.com/projects/code-editor/), from which
the inspiration to this, and some handy implementation hints, came.

### Stuff used to make this:

 * [marked](https://github.com/chjj) for Markdown parsing
 * [CodeMirror](http://codemirror.net/) for the awesome syntax-highlighted editor
 * [highlight.js](http://softwaremaniacs.org/soft/highlight/en/) for syntax highlighting in output code blocks
 * [js-deflate](https://github.com/dankogai/js-deflate) for gzipping of data to make it fit in URLs

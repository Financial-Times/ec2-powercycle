import boto3
import collections
from datetime import datetime
import pprint
import json
import sys, os
sys.path.append(os.path.dirname(os.path.realpath(__file__)) + '/lib')
from croniter import croniter
'''
Lambda function to stop and start EC2 instances

Usage:
To enable stop/start schedule on EC2 instance add tag businessHours: { "start": 0 8 * * *", "stop": "0 17 * * *" }

Author: Jussi Heinonen 
Date: 24.5.2016
URL: https://github.com/jussi-ft/ec2-powercycle
'''
tag = 'businessHours' # Set resource tag
dryrun = False # Set True to mock behaviour
ec = boto3.client('ec2')
startInstanceIds=[]
stopInstanceIds=[]

def getDesiredState(json_string):
    base = datetime.now()        
    try:
        schedule=json.loads(json_string)
        print 'Start schedule using croniter: ' + str(schedule['start'])
        print 'Stop schedule using croniter: ' + str(schedule['stop'])
        starttime = croniter(schedule['start'], base)
        stoptime = croniter(schedule['stop'], base)
        if stoptime.get_prev(datetime) > starttime.get_prev(datetime):
            print 'Stoptime event ' + str(stoptime.get_prev(datetime)) + ' is more recent than starttime event ' + str(starttime.get_prev(datetime)) + '. Instance should be stopped'
            return 'stopped'
        else:
            print 'Starttime event ' + str(starttime.get_prev(datetime)) + ' is more recent than stoptime event ' + str(stoptime.get_prev(datetime)) + '. Instance should be running'
            return 'running'
    except Exception, e:        
        return False
        

def handler(event = False, context = False):    
    reservations = ec.describe_instances(
    Filters=[
    {'Name': 'tag:' + tag, 'Values': ['*'],
    },]
    ).get('Reservations', [])
    
    instances = sum(
            [
                [i for i in r['Instances']]
                for r in reservations
            ], [])
    if str(len(instances)) > 1:
        extension = 's'
    print 'Found ' + str(len(instances)) + ' instance' + extension + ' with tag ' + tag
    print "InstanceIDs with tag " + tag + ':'
    for element in instances:
        print '\t * ' + str(element['InstanceId'])
         
    def get_resoure_tags(data):
        tags = {}
        for item in data:
            tmplist = item.values()
            tags[tmplist[1]] = tmplist[0] 
        return tags
    
    for instance in instances:
        #print 'instance details'
        print '________________'
        #pprint.pprint(instance)
        resource_tags = get_resoure_tags(instance['Tags'])
        try:
            desired_state=getDesiredState(resource_tags[tag])
            if desired_state == 'stopped' and str(instance['State']['Name']) == 'running':
                print 'Instance ' + instance['InstanceId'] + ' business hours are ' + resource_tags[tag]
                print 'Current status of instance is: ' +  str(instance['State']['Name']) + ' . Stopping instance.'
                stopInstanceIds.append(instance['InstanceId'])                            
            elif desired_state == 'running' and str(instance['State']['Name']) == 'stopped':
                print 'Instance ' + instance['InstanceId'] + ' business hours are ' + resource_tags[tag]
                print 'Current status of instance is: ' +  str(instance['State']['Name']) + ' . Starting instance.'
                startInstanceIds.append(instance['InstanceId'])
            elif not desired_state:
                print 'Error processing JSON document: ' + resource_tags[tag] + ' on instance ' + instance['InstanceId']
            else: 
                print 'InstanceID ' + str(instance['InstanceId']) + ' already in desired state: ' + str(desired_state)            
        except Exception, e:
            print 'Error: ' + str(e)
    if len(startInstanceIds) > 0:
        manageInstance(startInstanceIds, 'start')
    if len(stopInstanceIds) > 0:
        manageInstance(stopInstanceIds, 'stop')
    sys.exit(0)
    

def json_file_processor(fname):
    try:  
        os.path.isfile(fname)
        return json.loads(open(fname).read())
    except Exception, e:
        print 'File not found in ' + str(os.getcwd()) + ': ' + str(e) 
        sys.exit(1)
        
def manageInstance(idlist, action):
    if action == 'start':
        try:
            response = ec.start_instances(
                InstanceIds=idlist,
                DryRun=dryrun
                )
            print 'AWS response: ' + str(response)
            print 'Start_instances command issued for the following instances'
            for each in idlist:
                print '\t * ' + each
        except Exception, e:
            print 'Failed to issue start_instances command to list of instances: ' + str(e)
            for each in idlist:
                print '\t * ' + each
    elif action == 'stop':
        try:
            response = ec.stop_instances(
                InstanceIds=idlist,
                DryRun=dryrun
                )
            print 'AWS response: ' + str(response)
            print 'Stop_instances command issued for the following instances'
            for each in idlist:
                print '\t * ' + each
        except Exception, e:
            print 'Failed to issue stop_instances command to list of instances: ' + str(e)
            for each in idlist:
                print '\t * ' + each
    else:
        print 'Got gibberish action ' + str(action) + ' and I do not know what to do'
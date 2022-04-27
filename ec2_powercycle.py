    #!/bin/python
    # -*- coding: utf-8 -*-

import boto3, re
import collections
from datetime import datetime
from time import gmtime, strftime
import pprint
import json
import sys, os
sys.path.append(os.path.dirname(os.path.realpath(__file__)) + '/lib')
from croniter import croniter
import requests

'''
Lambda function to stop and start EC2 instances

Usage:
To enable stop/start schedule on EC2 instance add tag businessHours: { "start": 0 8 * * *", "stop": "0 17 * * *" }

Author: Jussi Heinonen 
Date: 21.7.2016
URL: https://github.com/jussi-ft/ec2-powercycle
'''
tag = 'asgLifecycle'  # Set resource tag
ENV_TAG = 'environment'  # The name of the AWS tag holding the type of environment.
exclude_env_tags = ['p']  # Value of the environment tags that should be excluded from powercycle
ec = boto3.client('ec2')
aws_scaling_client = boto3.client('autoscaling')


def handler(event = False, context = False):
    print('### START - ' + strftime("%a, %d %b %Y %H:%M:%S +0000", gmtime()) + ' ###')
    printBuildInfo()
    try:
        if type(event) is str:
            data = json.loads(event)
            print('event JSON doc loaded')
        else:
            data = event
        if data['DryRun'] in 'True':
            dryrun = True
            print('DryRun is ' + str(dryrun))
    except Exception as e:
        dryrun = False
    if len(exclude_env_tags) > 0:
        print('Excluding instances with environment tag values: ' + str(exclude_env_tags))

    handle_auto_scaling_groups(dryrun)

    handle_ec2_instances(dryrun)
    print('### END - ' + strftime("%a, %d %b %Y %H:%M:%S +0000", gmtime()) + ' ###')


def getDesiredState(json_string):
    base = datetime.now()        
    try:
        schedule = json.loads(json_string)
        print('Start schedule: ' + str(schedule['start']))
        print('Stop schedule: ' + str(schedule['stop']))
        starttime = croniter(schedule['start'], base)
        stoptime = croniter(schedule['stop'], base)
        if stoptime.get_prev(datetime) > starttime.get_prev(datetime):
            print('Stop event ' + str(stoptime.get_prev(datetime)) + ' is more recent than start event ' + str(starttime.get_prev(datetime)) + '. Desired state: stopped')
            return 'stopped'
        else:
            print('Start event ' + str(starttime.get_prev(datetime)) + ' is more recent than stop event ' + str(stoptime.get_prev(datetime)) + '. Desired state: running')
            return 'running'
    except Exception as e:
        print('Error: ' + str(e))
        return False



def get_resource_tags(data):
    tags = {}
    for item in data:
        tags[item['Key']] = item['Value']
    return tags


def handle_auto_scaling_groups(dryrun):
    print("--- Start processing Auto Scaling Groups ")
    next_token = ''
    while next_token is not None:
        if next_token is not '':
            describe_result = aws_scaling_client.describe_auto_scaling_groups(NextToken=next_token)
        else:
            describe_result = aws_scaling_client.describe_auto_scaling_groups()
        next_token = describe_result.get('NextToken')

        raw_groups = describe_result.get('AutoScalingGroups')
        process_raw_groups(raw_groups, dryrun)
    print("--- End processing Auto Scaling Groups")
    print("")


def process_raw_groups(raw_groups, dryrun):
    for group in raw_groups:
        try:
            print('________________')
            print("Processing ASG: {}".format(group['AutoScalingGroupName']))
            group_tags = get_resource_tags(group['Tags'])

            if tag in group_tags:
                print("Found ASG '{}' with tag {}. Processing it".format(group['AutoScalingGroupName'], tag))
                process_tagged_group(group, group_tags, dryrun)
            else:
                print("ASG {} doesn't have the {} tag. Skipping it... ".format(group['AutoScalingGroupName'], tag))
        except Exception as e:
            print('Error: while processing ASG ' + group['AutoScalingGroupName'] + ": " + str(e))


def process_tagged_group(group, group_tags, dryrun):
    group_name = get_group_name(group)

    # Check if we should process the ASG based on the environment tag
    if ENV_TAG not in group_tags:
        print("ASG {} is missing the environment type through the {} tag. Excluding it from power cycle... ".format(group_name, tag))
        return
    if group_tags[ENV_TAG] in exclude_env_tags:
        print("ASG {} has the environment {}. Excluding it from power cycle... ".format(group_name, group_tags[ENV_TAG]))
        return

    inline_schedule_tag_from_remote_url(group_tags)
    desired_state = getDesiredState(group_tags[tag])

    if not desired_state:
        print('Error processing JSON document: ' + group_tags[tag] + ' on ASG ' + group_name)
        return
    bring_asg_to_desired_state(group, group_tags, desired_state, dryrun)


def get_asg_scaling_state(group, group_tags):
    scaling_state = json.loads(group_tags[tag])  # reading the scaling state from the same ec2 power cycle tag
    min_size = 1  # default value for min
    desired_capacity = 1  # default value for desired state
    max_size = group['MaxSize'] # keep the current set max size
    if 'min' in scaling_state:
        min_size = scaling_state['min']

    if 'desired' in scaling_state:
        desired_capacity = scaling_state['desired']

    if min_size > desired_capacity:
        print('Min ' + str(min_size) + ' was set bigger than desired ' + str(desired_capacity) +
              '. Setting min to desired')
        min_size = desired_capacity
    if desired_capacity > max_size:
        print('Desired ' + str(desired_capacity) + ' is set bigger than the current max value ' + str(max_size) +
              '. Setting max to desired')
        max_size = desired_capacity

    return {'min': min_size, 'desired': desired_capacity, 'max': max_size}


def get_group_name(group):
    return group['AutoScalingGroupName']


def bring_asg_to_desired_state(group, group_tags, desired_state, dryrun):
    group_name = get_group_name(group)
    print('ASG ' + group_name + ' business hours are ' + group_tags[tag] +
          ". Current state: { min: " + str(group['MinSize']) + ", desired: " + str(group['DesiredCapacity']) + " }.")

    if desired_state == 'stopped' and is_asg_up(group):
        print('Scaling down ASG ' + group_name)
        if not dryrun:
            aws_scaling_client.update_auto_scaling_group(AutoScalingGroupName=group_name, MinSize=0, DesiredCapacity=0)

    elif desired_state == 'running' and not is_asg_up(group):
        desired_scaling_state = get_asg_scaling_state(group, group_tags)
        print('Scaling up ASG ' + group_name + ' to: ' + str(desired_scaling_state))
        if not dryrun:
            aws_scaling_client.update_auto_scaling_group(
                AutoScalingGroupName=group_name,
                MinSize=desired_scaling_state['min'],
                DesiredCapacity=desired_scaling_state['desired'],
                MaxSize=desired_scaling_state['max'])
    else:
        print('ASG ' + group_name + ' is already in the desired state ' + desired_state)


def is_asg_up(group):
    return group['MinSize'] > 0 and group['DesiredCapacity'] > 0




def handle_ec2_instances(dryrun):
    print("--- Start processing EC2 instances ")

    startInstanceIds=[]
    stopInstanceIds=[]
    reservations = ec.describe_instances(
        Filters=[
            {'Name': 'tag:' + tag, 'Values': ['*'],
             }]
    ).get('Reservations', [])

    instances = sum(
        [
            [i for i in r['Instances']]
            for r in reservations
        ], [])
    print('Found ' + str(len(instances)) + ' instances with tag ' + tag)
    if len(instances) > 0:
        print("InstanceIDs with tag " + tag + ':')
        for element in instances:
            print('\t * ' + str(element['InstanceId']))
    for instance in instances:
        #print('instance details')
        print('________________')
        #pprint.pprint(instance)
        resource_tags = get_resource_tags(instance['Tags'])
        try:
            inline_schedule_tag_from_remote_url(resource_tags)

            desired_state = getDesiredState(resource_tags[tag])
            if desired_state == 'stopped' and str(instance['State']['Name']) == 'running':
                print('Instance ' + instance['InstanceId'] + ' business hours are ' + resource_tags[tag])
                print('Current status of instance is: ' +  str(instance['State']['Name']) + ' . Stopping instance.')
                try:
                    if resource_tags[ENV_TAG] in exclude_env_tags:
                        print(instance['InstanceId'] + ' has environment tag ' +  resource_tags[ENV_TAG] + ' . Excluding from powercycle.')
                    else:
                        stopInstanceIds.append(instance['InstanceId'])
                except Exception as e:
                    print(instance['InstanceId'] + ' is missing environment tag. Excluding from powercycle.')
            elif desired_state == 'running' and str(instance['State']['Name']) == 'stopped':
                print('Instance ' + instance['InstanceId'] + ' business hours are ' + resource_tags[tag])
                print('Current status of instance is: ' +  str(instance['State']['Name']) + ' . Starting instance.')
                try:
                    if resource_tags[ENV_TAG] in exclude_env_tags:
                        print(instance['InstanceId'] + ' has environment tag ' +  resource_tags[ENV_TAG] + ' . Excluding from powercycle.')
                    else:
                        startInstanceIds.append(instance['InstanceId'])
                except Exception as e:
                    print(instance['InstanceId'] + ' is missing environment tag. Excluding from powercycle.')
            elif not desired_state:
                print('Error processing JSON document: ' + resource_tags[tag] + ' on instance ' + instance['InstanceId'])
            else:
                print('InstanceID ' + str(instance['InstanceId']) + ' already in desired state: ' + str(desired_state))
        except Exception as e:
            print('Error: ' + str(e))
    if len(startInstanceIds) > 0:
        manageInstance(startInstanceIds, 'start', dryrun)
        startInstanceIds = None # Unset variable
    if len(stopInstanceIds) > 0:
        manageInstance(stopInstanceIds, 'stop', dryrun)
        stopInstanceIds = None # Unset variable

    print("--- End processing EC2 instances ")
    print("")


def inline_schedule_tag_from_remote_url(resource_tags):
    if re.search("http", resource_tags[tag]):
        try:
            print('Fetching document from ' + resource_tags[tag])
            r = requests.get(resource_tags[tag])
            resource_tags[tag] = json.dumps(r.json())
        except Exception as e:
            print('Failed to load document ' + resource_tags[tag])


def manageInstance(idlist, action, dryrun):
    if action == 'start':
        try:
            response = ec.start_instances(
                InstanceIds=idlist,
                DryRun=dryrun
                )
            print('AWS response: ' + str(response))
            print('Start_instances command issued for the following instances')
            for each in idlist:
                print('\t * ' + each)
        except Exception as e:
            print('Failed to issue start_instances command to list of instances: ' + str(e))
            for each in idlist:
                print('\t * ' + each)
    elif action == 'stop':
        try:
            response = ec.stop_instances(
                InstanceIds=idlist,
                DryRun=dryrun
                )
            print('AWS response: ' + str(response))
            print('Stop_instances command issued for the following instances')
            for each in idlist:
                print('\t * ' + each)
        except Exception as e:
            print('Failed to issue stop_instances command to list of instances: ' + str(e))
            for each in idlist:
                print('\t * ' + each)
    else:
        print('Got gibberish action ' + str(action) + ' and I do not know what to do')
    
def printBuildInfo():
    try:
        f = open('build.info', 'r')
        print(f.read())
        f.close()
    except:
        pass    

#!/usr/bin/env python
# -*- coding: utf-8 -*-

from croniter import croniter
from datetime import datetime
from functions import *
from time import gmtime, strftime
import boto3, re
import collections
import json
import pprint
import requests
import sys, os

sys.path.append(os.path.dirname(os.path.realpath(__file__)) + '/lib')


class Worker():
    def __init__(self, **kwargs):
        self.client = boto3.client('ec2')
        self.now = datetime.now()

        self.exclude_env_tags = kwargs.get('exclude_env_tags', ['p'])
        self.tag = kwargs.get('tag', 'ec2Powercycle')
        self.dryrun = kwargs.get('dryrun', False)
        self.log = kwargs.get('log', True)

        if self.log:
            self._log('Initialised Worker instance')


    def go(self):
        start = []
        stop = []
        remove = []

        if self.log:
            self._log('Taking care of business')

        for reservation in self.reservations():
            for instance in reservation['instances']:
                if self.log:
                    self._log("Interrogating {}".format(instance['InstanceId']))

                if self.is_start(instance):
                    start.extend(instance['InstanceId'])
                if self.is_stop(instance):
                    stop.extend(instance['InstanceId'])
                if self.is_remove(instance):
                    remove.extend(instance['InstanceId'])

        self.start(start)
        self.stop(stop)
        self.remove(remove)


    def reservations(self):
        return self.client.describe_instances(
            Filters=[
                {
                    'Name': 'tag:' + self.tag, 'Values': ['*'],
                }
            ]
        ).get('Reservations', [])


    def is_start(self, instance):
        return self._is_state(instance, 'start')


    def is_stop(self, instance):
        return self._is_state(instance, 'stop')


    def is_remove(self, instance):
        return self._is_state(instance, 'remove')


    def start(self, instances):
        self._set_instances_state(instances, 'start')


    def stop(self, instances):
        self._set_instances_state(instances, 'stop')


    def remove(self, instances):
        self._set_instances_state(instances, 'remove')


    def _is_state(self, instance, state):
        t = self._parse_tags(instance['Tags'])
        if t:
            return self._is_time(t[state]) and instance['State']['Name'] in {'start': ['Stopped', 'Stopping'],
                                                                            'stop': ['Started', 'Starting'],
                                                                            'remove': ['Stopped', 'Started']}[state]
        return False


    def _parse_tags(self, tags):
        if not self._is_ignored(tags):
            return next( (json.loads(item['Value']) for item in tags if item['Key'] == self.tag), None)
        return None


    def _is_time(self, cron):
        return self.now >= croniter(cron, self.now).get_next(datetime)


    def _is_ignored(self, tags):
        return next( (item['Value'] in self.exclude_env_tags for item in tags if item['Key'] == 'environment'), False)


    def _set_instances_state(self, instances, state):
        if len(instances) == 0:
            return

        if self.log:
            self._log("Setting instances '{}' to state {}".format((', ').join(instances), state))

        {'start': self.client.start_instances,
         'stop': self.client.stop_instances,
         'remove': self.client.terminate_instances}[state](
             InstanceIds = instances,
             DryRun = self.dryrun
         )

    def _log(self, message):
        print "{}: {}".format(self.now, message)

def handler(event, context):
    Worker().go()


if __name__ == '__main__':
    handler({}, {})

#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pprint
import json
import os

def json_file_open(fname):
    try:
        os.path.isfile(fname)
        return json.loads(open(fname).read())
    except Exception, e:
        print 'File not found in ' + str(os.getcwd()) + ': ' + str(e)
        sys.exit(1)

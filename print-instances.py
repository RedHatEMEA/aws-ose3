#!/usr/bin/python

import json
import random
import string
import sys

j = json.loads(sys.stdin.read())
for r in j["Reservations"]:
    for i in r["Instances"]:
        if i["State"]["Name"] == "running":
            print '"' + '","'.join([i["Tags"][0]["Value"], i["NetworkInterfaces"][0]["Association"]["PublicIp"], i["NetworkInterfaces"][0]["Association"]["PublicDnsName"],"".join(random.sample(string.lowercase, 8))]) + '"'


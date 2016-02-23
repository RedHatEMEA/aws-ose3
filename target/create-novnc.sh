#!/bin/bash -x

oadm new-project vnc
oc new-app -n vnc --docker-image=jimminter/novnc -e HOSTPORT=$(hostname):5900
oc expose -n vnc svc/novnc --name no

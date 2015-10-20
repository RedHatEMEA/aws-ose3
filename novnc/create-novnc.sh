#!/bin/bash -x 

[ $(oc project | grep vnc | wc -l) -gt 0 ] && oc delete project vnc && sleep 5
oadm new-project vnc --admin=system:admin
oc project vnc
oc create -f novnc.yaml 
oc new-app novnc 
oc env dc/novnc HOSTPORT=$(hostname):5900
oc get is
oc describe is fedora
sleep 10
oc start-build novnc
[ $? -ne 0 ] && echo "trying again...." && sleep 10 && oc start-build novnc
sleep 3
oc build-logs novnc-1

#!/bin/bash -x

oc delete project vnc
while [ $(oc get project vnc --no-headers | wc -l) -gt 0 ]; do
   echo "Waiting for project to be deleted"
   oc get project vnc
   sleep 1
done

oadm new-project vnc
oc project vnc

while [  $(oc get routes no | wc -l) -gt 0 ]; do
   echo "old route still with us, waiting for it to disappear"
   oc delete route no
   oc get route no
   sleep 2
done

oc new-app -n vnc --docker-image=jimminter/novnc -e HOSTPORT=$(hostname):5900

echo "creating new route"
oc create -f - <<API
apiVersion: v1
kind: Route
metadata:
  labels:
    app: novnc
  name: "no"
spec:
  tls:
    termination: edge
  to:
    kind: Service
    name: novnc
API


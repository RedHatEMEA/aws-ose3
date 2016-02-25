#!/bin/bash -x

oadm new-project vnc
oc delete all --all -n vnc
oc new-app -n vnc --docker-image=jimminter/novnc -e HOSTPORT=$(hostname):5900
oc create -n vnc -f - <<EOF
apiVersion: v1
kind: Route
metadata:
  name: "no"
spec:
  tls:
    termination: edge
  to:
    kind: Service
    name: novnc
EOF

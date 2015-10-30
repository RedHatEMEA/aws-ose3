#!/bin/bash -x

docker pull docker.io/fedora:22
oadm new-project vnc
oc project vnc
oc process -f novnc.yaml | oc create -f -
oc env dc novnc HOSTPORT=$(hostname):5900
sleep 30
oc get is fedora
oc start-build --follow novnc
oc project default

#!/bin/bash -e

oc process monster -n openshift | oc create -n demo -f -
oc start-build --follow monster -n demo
oc delete all --all -n demo

oc process nodejs-mongodb-example -n openshift | oc create -n demo -f -
oc start-build --follow nodejs-mongodb-example -n demo
oc delete all --all -n demo

for i in $(oc get images | grep sha256 | awk '{print $1;}'); do
  oc delete image $i
done

rm /home/cloud-user/*

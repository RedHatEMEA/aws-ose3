#!/bin/bash -ex

oc process monster -n openshift | oc create -n demo -f -
for ((i=0; i<360; i++)); do
  if oc get build monster-1 -n demo | grep -q Complete; then
    break
  elif oc get build monster-1 -n demo | egrep -qe 'Error|Failed'; then
    echo "WARNING: build failed"
    break
  elif [ $i -lt 359 ]; then
    sleep 5
  else
    echo "WARNING: build timed out"
    break
  fi
done
oc delete all --all -n demo

oc process nodejs-mongodb-example -n openshift | oc create -n demo -f -
for ((i=0; i<360; i++)); do
  if oc get build nodejs-mongodb-example-1 -n demo | grep -q Complete; then
    break
  elif oc get build nodejs-mongodb-example-1 -n demo | egrep -qe 'Error|Failed'; then
    echo "WARNING: build failed"
    break
  elif [ $i -lt 359 ]; then
    sleep 5
  else
    echo "WARNING: build timed out"
    break
  fi
done
oc delete all --all -n demo

for i in $(oc get images | grep sha256 | awk '{print $1;}'); do
  oc delete image $i
done

rm /home/cloud-user/*

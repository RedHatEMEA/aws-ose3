#!/bin/bash

oc delete all --all -n demo
for i in $(oc get images | grep sha256 | awk '{print $1;}'); do
  oc delete image $i
done
rm /home/cloud-user/*

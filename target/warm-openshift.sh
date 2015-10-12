#!/bin/bash

oc process monster -n openshift | oc create -n demo -f -
oc process nodejs-mongodb-example -n openshift | oc create -n demo -f -

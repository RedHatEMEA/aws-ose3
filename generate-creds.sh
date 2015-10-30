#!/bin/bash

RUNNAME=$1
[ -z "$RUNNAME" ] && echo "** Please provide RunName tag value **" && exit 1

aws ec2 describe-instances --filters "Name=tag:RunName,Values=$RUNNAME" | python bin/print-instances.py > creds.csv

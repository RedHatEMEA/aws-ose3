#!/bin/bash

filter=$1
[ "${filter}" == "" ] && echo "** Please provide RunName tag value **" && exit 1

[ -e creds.csv ] && rm -f creds.old && mv creds.{csv,old} && rm -f creds.csv

aws ec2 describe-instances --filters "Name=tag:RunName,Values=${filter}" | python print-instances.py > creds.csv




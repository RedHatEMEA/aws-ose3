#!/bin/bash

AMI=ami-1becd86c
KEYNAME=$USER
SECGROUP=sg-a4bc1ac0
SUBNET=subnet-7d690824
N=1

 aws ec2 run-instances --image-id $AMI --key-name $KEYNAME \
   --associate-public-ip-address \
   --security-group-ids $SECGROUP --instance-type m4.large \
   --subnet-id $SUBNET --ebs-optimized \
   --block-device-mappings '{"DeviceName":"/dev/sda1","Ebs":{"DeleteOnTermination":"true","VolumeType":"gp2"}}' \
   --count $N

# aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" | python print-instances.py >creds.csv

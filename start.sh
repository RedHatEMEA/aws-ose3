#!/bin/bash

. config

if [ $# -ne 1 ]; then
  echo usage: $0 number_of_instances_to_start
  exit 1
fi

RUNNAME=$(date +%Y%m%d%H%M%S)

echo "** Use RunName to select this batch of instances for future operations **"
echo "RunName=$RUNNAME"

instanceids=$(aws ec2 run-instances --image-id $AMI --key-name $KEYNAME \
  --associate-public-ip-address \
  --security-group-ids $SECGROUP --instance-type m4.large \
  --subnet-id $SUBNET --ebs-optimized \
  --block-device-mappings '{"DeviceName": "/dev/sda1", "Ebs": {"DeleteOnTermination": true, "VolumeType": "gp2"}}' \
  --count $1 | awk '/InstanceId/ {print $2}' | tr -d '",')

i=1
for instanceid in $instanceids; do
  aws ec2 create-tags --resources $instanceid --tags Key=Name,Value="ose3-$RUNNAME-$i" Key=RunName,Value="$RUNNAME"
  i=$((i+1))
done

aws ec2 describe-instances --filters "Name=tag:RunName,Values=$RUNNAME" | python bin/print-instances.py >creds.csv

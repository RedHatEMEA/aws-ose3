#!/bin/bash

. config

N=$1
[ "$N" == "" ] || [ "$N" -le "0" ] && echo "*** PLEASE PROVIDE THE NUMBER OF INSTANCES TO CREATE ***" && exit 1

# generate an ignore list
ignore=$(aws ec2 describe-instances | awk '/InstanceId/ {print $2}' | tr -d '",')

aws ec2 run-instances --image-id $AMI --key-name $KEYNAME \
  --associate-public-ip-address \
  --security-group-ids $SECGROUP --instance-type m4.large \
  --subnet-id $SUBNET --ebs-optimized \
  --block-device-mappings '{"DeviceName": "/dev/sda1", "Ebs": {"DeleteOnTermination": true, "VolumeType": "gp2"}}' \
  --count $N

RUNNAME=$(date +%Y%m%d%H%M%S)

echo "** Use RunName to select this batch of instances for future operations **"
echo "RunName=$RUNNAME"

# dump out a new list of instances creating using the above start command
id=1
aws ec2 describe-instances | awk '/InstanceId/ {print $2}' | tr -d '",' | while read instanceID
do
   if [[ ${ignore} != *"${instanceID}"* ]]; then
      aws ec2 create-tags --resources "$instanceID" --tags Key=Name,Value="ose3-$RUNNAME-$id" Key=RunName,Value="$RUNNAME"
      id=$((id+1))
   fi
done

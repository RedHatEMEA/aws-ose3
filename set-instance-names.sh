#!/bin/bash

id=1

aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" | grep InstanceId | awk '{print $2}' | cut -d '"' -f2 | while read instanceID
do
  echo "InstanceID: ${instanceID}, tagging with inst-${id}"
  aws ec2 create-tags --resources ${instanceID} --tags Key=Name,Value="inst-${id}"

  id=$((id+1))

done 

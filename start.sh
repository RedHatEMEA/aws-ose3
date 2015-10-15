#!/bin/bash 

AMI=ami-1becd86c
KEYNAME=$USER
SECGROUP=sg-a4bc1ac0
SUBNET=subnet-7d690824
N=2

# generate an ignore list
ignore=$(aws ec2 describe-instances | grep InstanceId | awk '{print $2}' | cut -d '"' -f2)

 aws ec2 run-instances --image-id $AMI --key-name $KEYNAME \
   --associate-public-ip-address \
   --security-group-ids $SECGROUP --instance-type m4.large \
   --subnet-id $SUBNET --ebs-optimized \
   --block-device-mappings '{"DeviceName":"/dev/sda1","Ebs":{"DeleteOnTermination":"true","VolumeType":"gp2"}}' \
   --count $N

# 

# remove any existing list of instances
[ -e instances.list ] && rm -f instances.oldlist && mv instances.{list,oldlist}
rm -f instances.list

id=1
tag=$(date +"%Y%d%m-%H%M")

echo "** Use RunName to select this batch of instances for future operations **"
echo "RunName=${tag}"

# dump out a new list of instances creating using the above start command
aws ec2 describe-instances | grep InstanceId | awk '{print $2}' | cut -d '"' -f2 | while read instanceID
do

   if [[ ${ignore} != *"${instanceID}"* ]]; then

      echo "${instanceID}" >> instances.list 
      aws ec2 create-tags --resources ${instanceID} --tags Key=Name,Value="inst-${tag}-${id}" Key=RunName,Value="${tag}"
      id=$((id+1))

   fi 

done



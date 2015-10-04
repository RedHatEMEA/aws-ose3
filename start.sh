#!/bin/bash

aws ec2 run-instances --image-id ami-1becd86c --key-name $USER --security-group-ids sg-bd8757d9 --instance-type m4.large --subnet-id subnet-a0bbe2c5 --ebs-optimized --block-device-mappings 'DeviceName=/dev/sda1,Ebs={DeleteOnTermination=true,VolumeType=io1,Iops=1200}'


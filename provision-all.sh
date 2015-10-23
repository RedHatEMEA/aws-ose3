#!/bin/bash -x

identity=${1}
[ "${identity}" = "" ] && echo "** PLEASE PROVIDE A PATH TO AWS IDENTITY CREDENTIALS (PEM FILE)**" && exit 255

mkdir -p log

hosts=()

while read line
do
  OLDIFS=$IFS;
  IFS=, vals=($line)
  IFS=$OLDIFS

  name=${vals[0]}
  ip=${vals[1]}
  dns=$(echo ${vals[2]} | cut -d '"' -f2)
  pwd=$(echo ${vals[3]} | cut -d '"' -f2)

  hosts+=("${dns}")

  echo "*** Updating password for ${name}"
  bin/issh cloud-user@${dns} -i ${identity} -tt "echo ${pwd} | sudo passwd demo --stdin" &>log/log-pwd-$dns < /dev/null
  
  [ $? -ne 0 ] && echo "*** ERROR $? RETURNED FOR ${dns} WHILST SETTING DEMO PASSWORD, bailing ***" && exit 1

  scp -i ${identity} -S bin/issh target/* cloud-user@$dns: &>log/log-script-tx-$dns

  [ $? -ne 0 ] && echo "*** ERROR $? RETURNED FOR ${dns} WHILST COPYING SCRIPTS, bailing ***" && exit 1

  bin/issh -i ${identity} -tt cloud-user@$dns sudo 'bash -c "cd /home/cloud-user; ./openshift-aws-reip.sh"' &>log/log-ip-$dns < /dev/null &

  [ $? -ne 0 ] && echo "*** ERROR $? RETURNED FOR ${dns} WHILST RUNNING REIP SCRIPT, bailing ***" && exit 1

done < creds.csv

echo "*** WAITING FOR IPs TO BE UPDATED ***"
wait

for dns in "${hosts[@]}"
do

  bin/issh -i ${identity} -tt cloud-user@$dns sudo 'sed -i -e "/^PermitEmptyPasswords yes/ d" /etc/ssh/sshd_config' &>>log/log-ip-$dns < /dev/null
  bin/issh -i ${identity} -tt cloud-user@$dns sudo 'sed -i -e "/^PasswordAuthentication no/ d" /etc/ssh/sshd_config' &>>log/log-ip-$dns < /dev/null
  bin/issh -i ${identity} -tt cloud-user@$dns sudo 'systemctl restart sshd.service' &>>log/log-ip-$dns < /dev/null
  
  bin/issh -i ${identity} -tt cloud-user@$dns nohup sudo ./warm-ebs.sh &>log/log-ebs-$dns < /dev/null &

done 

echo "*** WAITING FOR EBS TO WARM UP ***"
wait

for dns in "${hosts[@]}"
do

  bin/issh -i ${identity} -tt cloud-user@$dns 'bash -c "ps -ax|grep xvda"' &>>log/log-xvda-$dns < /dev/null

  [ $? -ne 0 ] && echo "*** ERROR $? RETURNED FOR ${dns} WHILST LOOKING FOR xvda ***" 

  bin/issh -i ${identity} -tt cloud-user@$dns sudo ./warm-openshift.sh &>log/log-warmup-$dns < /dev/null &
  
  [ $? -ne 0 ] && echo "*** ERROR $? RETURNED FOR ${dns} WHILST WARMING UP OPENSHIFT ***" 

done

echo "*** WAITING FOR OSE TO WARM UP ***"
wait

for dns in "${hosts[@]}"
do

  bin/issh -i ${identity} -tt cloud-user@$dns sudo ./cleanup.sh &>log/log-cleanup-$dns < /dev/null & 

done

echo "*** WAITING FOR CLEAN UP ***"
wait


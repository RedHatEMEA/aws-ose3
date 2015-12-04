#!/bin/bash -x

if [ "$identity" != "" ]; then
  identity="-i $identity"
fi

mkdir -p logs

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

  bin/issh cloud-user@${dns} ${identity} -tt "echo ${pwd} | sudo passwd demo --stdin" </dev/null &>logs/$dns-1-passwd
  [ $? -ne 0 ] && echo "*** ERROR $? RETURNED FOR ${dns} WHILST SETTING DEMO PASSWORD, bailing ***" && exit 1

  scp ${identity} -S bin/issh target/* cloud-user@$dns: &>logs/$dns-2-scp
  [ $? -ne 0 ] && echo "*** ERROR $? RETURNED FOR ${dns} WHILST COPYING SCRIPTS, bailing ***" && exit 1

  bin/issh ${identity} -tt cloud-user@$dns sudo 'bash -c "cd /home/cloud-user; ./openshift-aws-reip.sh"' </dev/null &>logs/$dns-3-reip &
done < creds.csv

echo "*** WAITING FOR REIP PROCESSES ***"
wait

for dns in "${hosts[@]}"
do
  bin/issh ${identity} -tt cloud-user@$dns sudo 'sed -i -e "/^PermitEmptyPasswords yes/ d" /etc/ssh/sshd_config' &>logs/$dns-4-sshd
  bin/issh ${identity} -tt cloud-user@$dns sudo 'sed -i -e "/^PasswordAuthentication no/ d" /etc/ssh/sshd_config' &>>logs/$dns-4-sshd
  bin/issh ${identity} -tt cloud-user@$dns sudo 'systemctl restart sshd.service' &>>logs/$dns-4-sshd
  bin/issh ${identity} -tt cloud-user@$dns sudo 'bash -c "cd /home/cloud-user; ./create-novnc.sh"' &>logs/$dns-5-novnc &
done

echo "*** WAITING FOR NOVNC PROCESSES ***"
wait

for dns in "${hosts[@]}"
do
  bin/issh ${identity} -tt cloud-user@$dns sudo ./warm-openshift.sh &>logs/$dns-6-warmup &
done

echo "*** WAITING FOR WARMUP PROCESSES ***"
wait

for dns in "${hosts[@]}"
do
  bin/issh ${identity} -tt cloud-user@$dns nohup sudo ./warm-ebs.sh &>logs/$dns-7-ebs
done

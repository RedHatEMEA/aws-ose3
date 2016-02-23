#!/bin/bash -x

if [ -n "$1" ]; then
  identity="-i $1"
fi

mkdir -p logs

hosts=()

while IFS=, read name ip dns password
do
  hosts+=("$dns")

  bin/issh $identity -tt cloud-user@$dns sudo passwd demo --stdin <<<$password &>logs/$dns-1-passwd
  [ $? -ne 0 ] && echo "Failed to set password on $dns (host not finished booting yet?), bailing" && exit 1

  scp $identity -S bin/issh target/* cloud-user@$dns: &>logs/$dns-2-scp
done <creds.csv

for dns in "${hosts[@]}"
do
  bin/issh $identity -tt cloud-user@$dns sudo ./warm-ebs.sh &>logs/$dns-3-ebs &
done

echo "*** WAITING FOR EBS WARMUP PROCESSES ***"
wait

for dns in "${hosts[@]}"
do
  bin/issh $identity -tt cloud-user@$dns sudo 'bash -c "cd /home/cloud-user; ./openshift-aws-reip.sh"' </dev/null &>logs/$dns-4-reip &
done

echo "*** WAITING FOR REIP PROCESSES ***"
wait

for dns in "${hosts[@]}"
do
  bin/issh $identity -tt cloud-user@$dns sudo 'sed -i -e "/^PermitEmptyPasswords yes/ d" /etc/ssh/sshd_config' &>logs/$dns-5-sshd
  bin/issh $identity -tt cloud-user@$dns sudo 'sed -i -e "/^PasswordAuthentication no/ d" /etc/ssh/sshd_config' >>logs/$dns-5-sshd 2>&1
  bin/issh $identity -tt cloud-user@$dns sudo 'systemctl restart sshd.service' >>logs/$dns-5-sshd 2>&1
  bin/issh $identity -tt cloud-user@$dns sudo 'bash -c "cd /home/cloud-user; ./create-novnc.sh"' &>logs/$dns-6-novnc &
done

echo "*** WAITING FOR NOVNC PROCESSES ***"
wait

for dns in "${hosts[@]}"
do
  bin/issh $identity -tt cloud-user@$dns sudo ./warm-openshift.sh &>logs/$dns-7-warmup &
done

echo "*** WAITING FOR OSE WARMUP PROCESSES ***"
wait

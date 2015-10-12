#!/bin/bash -ex

IPS="1.2.3.4 1.2.3.5 1.2.3.6"

mkdir -p log
for ip in $IPS; do
    #scp -S bin/issh target/* cloud-user@$ip: &>log/log-$ip &
    #bin/issh -tt cloud-user@$ip sudo 'bash -c "cd /home/cloud-user; ./openshift-aws-reip.sh"' &>log/log-$ip &
    #bin/issh -tt cloud-user@$ip sudo 'sed -i -e "/^PermitEmptyPasswords yes/ d" /etc/ssh/sshd_config' &>log/log2-$ip &
    #bin/issh -tt cloud-user@$ip sudo 'sed -i -e "/^PasswordAuthentication no/ d" /etc/ssh/sshd_config' &>log/log2-$ip &
    #bin/issh -tt cloud-user@$ip sudo 'systemctl restart sshd.service' &>log/log2-$ip &
    #bin/issh -tt cloud-user@$ip nohup sudo ./warm-ebs.sh &>log/log2-$ip &
    #bin/issh -tt cloud-user@$ip 'bash -c "ps -ax|grep xvda"' &>log/log2-$ip &
    #bin/issh -tt cloud-user@$ip sudo ./warm-openshift.sh &>log/log2-$ip &
    #bin/issh -tt cloud-user@$ip sudo ./cleanup.sh &>log/log2-$ip &
done
wait

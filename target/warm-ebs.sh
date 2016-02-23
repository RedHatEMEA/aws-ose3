#!/bin/bash

systemctl stop atomic-openshift-node
systemctl stop atomic-openshift-master
docker ps -aq | xargs docker rm -f

dd if=/dev/xvda of=/dev/null bs=1M &
PID=$!

while true; do
  sleep 10
  kill -SIGUSR1 $PID &>/dev/null || break
done

systemctl start atomic-openshift-master
systemctl start atomic-openshift-node

#!/bin/bash -x

if [ -n "$1" ]; then
  identity="-i $1"
fi

mkdir -p logs

hosts=()

while IFS=, read name ip dns password
do
  hosts+=("$dns")

  scp $identity -S bin/issh target/test-env.sh cloud-user@$dns: &>logs/$dns-2-scp
done <creds.csv

for dns in "${hosts[@]}"
do
  bin/issh $identity -tt cloud-user@$dns sudo 'bash -c "cd /home/cloud-user; ./test-env.sh"' &>logs/$dns-8-testenv &
done

echo "*** WAITING FOR TEST PROCESSES ***"
wait


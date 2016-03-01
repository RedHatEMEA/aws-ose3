#!/bin/bash -x

if [ -n "$1" ]; then
  identity="-i $1"
fi

ips=()

while IFS=, read name ip dns password
do
  ips+=("$ip")
done <creds.csv

for ip in "${ips[@]}"
do

  httpcode=$(curl -ksi https://no-vnc.apps.$ip.xip.io/vnc.html|grep "HTTP/1.1" | awk '{print $2}')
  echo "IP $ip responded $httpcode"

done



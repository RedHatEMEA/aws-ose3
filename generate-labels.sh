#!/bin/bash -e

mkdir -p labels

echo '"Instance Name","IP","Password","IMG"' >labels/data.csv

while IFS=, read name ip dns password
do
  qr="$(pwd)/labels/$ip.png"
  qrencode -o $qr "https://openshift.$ip.xip.io:8443/"
  echo \"$name\",\"$ip\",\"$password\",\"$qr\" >>labels/data.csv
done <creds.csv

glabels-3-batch -i labels/data.csv docs/labels.glabels -o labels/labels.pdf

#!/bin/bash -e

mkdir -p labels

echo '"Instance Name","IP","Password","IMG"' >labels/data.csv

while read line; do
  OLDIFS=$IFS;
  IFS=, vals=($line)
  IFS=$OLDIFS

  name=$(tr -d '"' <<< ${vals[0]})
  ip=$(tr -d '"' <<< ${vals[1]})
  password=$(tr -d '"' <<< ${vals[3]})

  qr="$(pwd)/labels/$ip.png"

  qrencode -o $qr "https://openshift.$ip.xip.io:8443/"

  echo \"$name\",\"$ip\",\"$password\",\"$qr\" >>labels/data.csv
done < creds.csv

glabels-3-batch -i labels/data.csv docs/labels.glabels -o labels/labels.pdf

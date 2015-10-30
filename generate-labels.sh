#!/bin/bash -e

mkdir -p labels

echo '"Instance Name","IP","DNS","Password","IMG","Host","Domain"' >labels/data.csv

while read line; do
  OLDIFS=$IFS;
  IFS=, vals=($line)
  IFS=$OLDIFS

  name=$(tr -d '"' <<< ${vals[0]})
  ip=$(tr -d '"' <<< ${vals[1]})
  dns=$(tr -d '"' <<< ${vals[2]})
  password=$(tr -d '"' <<< ${vals[3]})

  hostname=${dns%%.*}
  domain=${dns#*.}

  qr="$(pwd)/labels/$dns.png"

  qrencode -o $qr "https://$dns:8443/"

  echo \"$name\",\"$ip\",\"$dns\",\"$password\",\"$qr\",\"$hostname\",\"$domain\" >>labels/data.csv
done < creds.csv

glabels-3-batch -i labels/data.csv docs/labels.glabels -o labels/labels.pdf

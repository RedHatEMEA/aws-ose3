#!/bin/bash -ex

mkdir -p qrcodes
output=label-data.csv

echo "\"Instance Name\",IP,DNS,Password,IMG,Host,Domain" > ${output}

while read line
do
  OLDIFS=$IFS;
  IFS=, vals=($line)
  IFS=$OLDIFS

  name=${vals[0]}
  ip=${vals[1]}
  dns=$(echo ${vals[2]} | cut -d '"' -f2)
  hnm=$(echo $dns | cut -d '.' -f1)
  dmn=$(echo $dns | cut -d '.' -f2-)
  pwd=$(echo ${vals[3]} | cut -d '"' -f2)
  img="qrcodes/${dns}.png"

  /usr/bin/qrencode -o ${img} "https://${dns}:8443/"

  echo "${name},${ip},\"${dns}\",\"${pwd}\",\"$(pwd)/${img}\",\"${hnm}\",\"${dmn}\"" >> ${output}

done < creds.csv

glabels-3-batch -i label-data.csv merge.glabels

#evince output.pdf

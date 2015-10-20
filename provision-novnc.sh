#!/bin/bash -ex

identity=${1}
[ "${identity}" = "" ] && echo "** PLEASE PROVIDE A PATH TO AWS IDENTITY CREDENTIALS (PEM FILE)**" && exit 255

mkdir -p log

while read line
do
  OLDIFS=$IFS;
  IFS=, vals=($line)
  IFS=$OLDIFS

  name=${vals[0]}
  ip=${vals[1]}
  dns=$(echo ${vals[2]} | cut -d '"' -f2)
  pwd=$(echo ${vals[3]} | cut -d '"' -f2)


  scp -i ${identity} -S bin/issh novnc/* cloud-user@$dns: &>log/log-vnc-$dns
  bin/issh -i ${identity} -tt cloud-user@$dns sudo 'bash -c "cd /home/cloud-user; ./create-novnc.sh"' &>log/log-vnc-$dns < /dev/null &
done < creds.csv

echo "*** WAITING FOR VNC TO PROVISION ***"
wait



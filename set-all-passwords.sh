#!/bin/bash 

identity=${1}
if [ "${identity}" = "" ]
then
   echo "** PLEASE PROVIDE A PATH TO AWS IDENTITY CREDENTIALS (PEM FILE)**" 
   exit 255
fi

while read line
do
  OLDIFS=$IFS;
  IFS=, vals=($line)
  IFS=$OLDIFS

  name=${vals[0]}
  ip=${vals[1]}
  dns=$(echo ${vals[2]} | cut -d '"' -f2)
  pwd=$(echo ${vals[3]} | cut -d '"' -f2)

  echo "*** Updating password for ${name}"
  ssh -o StrictHostKeyChecking=no cloud-user@${dns} -i ${identity} -tt "echo ${pwd} | sudo passwd demo --stdin" < /dev/null

done < creds.csv

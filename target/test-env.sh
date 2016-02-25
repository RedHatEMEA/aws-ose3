#!/bin/bash -x

oc delete all --all -n demo
oc delete all --all -n prod

oc project demo

oc new-app monster

sleep 5

lastbuild=$(oc get builds --no-headers | tail -n 1 | awk '{print $1}')
checks=0
while true ; do

laststatus=$(oc get builds --no-headers | tail -n 1 | awk '{print $4}')
checks=$((checks+1))

case $laststatus in

   "")
      echo "No build yet..."
      [[ $checks -gt 30 ]] && echo "ERROR: No build after 3 minutes" && exit 1
   ;;
   Pending)
      echo "Build is pending"
      [[ $checks -gt 30 ]] && echo "ERROR: No build after 3 minutes" && exit 1
   ;;
   Running)
      echo "Build still running"
   ;;
   Complete)
      echo "Build completed"
      break
   ;;
   *)
      echo "ERROR: $laststatus"
      exit 1
esac

sleep 5

done

# get service IP
serviceip=$(oc get service monster --no-headers | awk '{print $2}')
[[ "$serviceip" = "" ]] && echo "ERROR: No service" && exit 1

checks=0
while true ; do

  httpcode=$(curl -is http://$serviceip:8080 | grep "HTTP/1.1" | awk '{print $2}')
  checks=$((checks+1))

  [[ $httpcode -eq 200 ]] && echo "Service responding to requests" && break

  echo "Service returned HTTP code: $httpcode"
  [[ $checks -gt 36 ]] && echo "ERROR: Service unreachable after 3 mins" && exit 1

  sleep 5

done

extroute=http://$(oc get route monster --no-headers | awk '{print $2}')
checks=0
while true ; do

  httpcode=$(curl -is $extroute | grep "HTTP/1.1" | awk '{print $2}')
  checks=$((checks+1))

  [[ $httpcode -eq 200 ]] && echo "Route responding to requests" && break

  echo "Route returned HTTP code: $httpcode"
  [[ $checks -gt 6 ]] && echo "ERROR: route unreachable after 30 seconds" && exit 1

  sleep 5
done

oc project prod

oc new-app monster-prod

checks=0
while true; do

   mysqlpod=$(oc get pods | grep monster-mysql | awk '{print $2}')
   checks=$((checks+1))

   [[ "$mysqlpod" = "1/1" ]] && echo "MySQL running" && break

   echo "MySQL status: $mysqlpod"
   [[ $checks -gt 36 ]] && echo "ERROR: mysql not running after 3 mins" && exit

   sleep 5
done

oc tag monster:latest monster:prod -n demo

extroute=http://$(oc get route monster --no-headers | awk '{print $2}')
checks=0
while true ; do

  httpcode=$(curl -is $extroute | grep "HTTP/1.1" | awk '{print $2}')
  checks=$((checks+1))

  [[ $httpcode -eq 200 ]] && echo "Route responding to requests" && break

  echo "Route returned HTTP code: $httpcode"
  [[ $checks -gt 6 ]] && echo "ERROR: route unreachable after 30 seconds" && exit 1

  sleep 5
done


echo "******* ALL TESTS PASSED *********"
oc delete all --all -n demo
oc delete all --all -n prod


#!/bin/bash -ex

IP=www.xxx.yyy.zzz
PW=abcdefgh
bin/issh -t cloud-user@$IP sudo 'bash -c "echo '$PW' | passwd demo --stdin"'

#!/bin/bash

fio --readonly - <<EOF
[volume-initialize]
filename=/dev/xvda
rw=read
bs=256k
iodepth=128
ioengine=libaio
direct=1
EOF

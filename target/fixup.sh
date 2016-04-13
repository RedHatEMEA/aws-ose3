#!/bin/bash -x

mv /etc/sysconfig/network-scripts/ifcfg-eth0.vmimport /etc/sysconfig/network-scripts/ifcfg-eth0
cat >/etc/sysconfig/network-scripts/ifcfg-lo <<EOF
DEVICE=lo
IPADDR=127.0.0.1
NETMASK=255.0.0.0
NETWORK=127.0.0.0
# If you're having problems with gated making 127.0.0.0/8 a martian,
# you can change this to something else (255.255.255.255, for example)
BROADCAST=127.255.255.255
ONBOOT=yes
NAME=loopback
EOF

for svc in NetworkManager atomic-openshift-master-ipcfg atomic-openshift-master atomic-openshift-node-ipcfg atomic-openshift-node atomic-openshift-routewatcher atomic-openshift-dns-intercept atomic-openshift-auth; do
    service $svc restart
    sleep 2
done

sleep 60

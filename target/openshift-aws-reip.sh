#!/bin/bash -ex

sleep -- $((300 - $(cut -d. -f1 /proc/uptime))) || true

PUBIP=$(curl -s 169.254.169.254/latest/meta-data/public-ipv4)
PRIVIP=$(ip -4 addr show dev eth0 | sed -n '/inet / { s!.*inet !!; s!/.*!!; p; }')
PUBHN=openshift.$PUBIP.xip.io
PRIVHN=ip-${PRIVIP//./-}.eu-west-1.compute.internal

hostname $PRIVHN

rm -f /etc/NetworkManager/dispatcher.d/99-hosts

cat >/etc/hosts <<EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
$PRIVIP  openshift.example.com $PRIVHN $PUBHN
EOF

rm -f /usr/local/libexec/atomic-openshift-{master-ipcfg,node-ipcfg}.py /lib/systemd/system/atomic-openshift-{master-ipcfg,node-ipcfg}.service
systemctl daemon-reload

cp atomic-openshift-dns-intercept.py /usr/local/libexec
systemctl restart atomic-openshift-dns-intercept

python -c 'import random; print "%02X" % random.randint(11, 1000000000)' >/etc/origin/master/ca.serial.txt

./reip.py $PRIVHN $PUBHN $PRIVIP $PUBIP $PUBIP.xip.io

systemctl restart atomic-openshift-routewatcher

cat >/home/demo/.kube/config <<EOF
kind: Config
apiVersion: v1
clusters:
- cluster:
    server: https://$PUBHN:8443
  name: ${PUBHN//./-}:8443
contexts:
- context:
    cluster: ${PUBHN//./-}:8443
  name: ${PUBHN//./-}:8443
current-context: ${PUBHN//./-}:8443
EOF

chown -R demo:demo /home/demo

cat >/usr/lib64/firefox/firefox.cfg <<EOF
//
pref("browser.startup.homepage", "https://$PUBHN:8443/console/");
pref("startup.homepage_override_url", "");
pref("startup.homepage_welcome_url", "");
pref("signon.rememberSignons", false);
EOF

echo 'Done.'
echo "https://$PUBHN:8443/"
echo 'dont forget to set the password for the demo user, and warm up the EBS volume'

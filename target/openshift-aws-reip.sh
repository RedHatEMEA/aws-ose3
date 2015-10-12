#!/bin/bash -ex

PUBIP=$(curl -s 169.254.169.254/latest/meta-data/public-ipv4)
PRIVIP=$(ip -4 addr show dev eth0 | sed -n '/inet / { s!.*inet !!; s!/.*!!; p; }')
OLDHN=openshift.example.com
NEWHN=ec2-${PUBIP//./-}.eu-west-1.compute.amazonaws.com
PATHS="/etc/hostname /etc/openshift /home/demo/.kube/config /home/demo/.m2/settings.xml /home/demo/git /root/.kube/config /usr/lib64/firefox/firefox.cfg /usr/share/doc/demobuilder"

stop() {
  systemctl stop openshift-routewatcher
  systemctl stop openshift-node
  oc project default
  oc delete pods --all
  systemctl stop openshift-master
  systemctl stop openshift-auth
  systemctl stop openshift-dns-intercept
  systemctl stop docker
  umount /var/lib/openshift/openshift.local.volumes/pods/*/volumes/*/*
}

start() {
  systemctl start docker
  docker ps -aq |xargs docker rm -f || true
  systemctl start openshift-auth
  /usr/local/libexec/openshift-master-ipcfg.py 
  systemctl start openshift-master
  oc delete hostsubnet openshift.example.com || true
  /usr/local/libexec/openshift-node-ipcfg.py 
  systemctl start openshift-node
  systemctl start openshift-routewatcher
}

save() {
  for i in $PATHS /var/lib/openshift; do
    [ -e $i-clean ] || cp -a $i $i-clean
  done
}

reset() {
  for i in $PATHS /var/lib/openshift; do
    rm -rf $i
    cp -a $i-clean $i
  done
}

stop
#save
#reset

cp index.html /usr/share/doc/demobuilder/index.html

find $PATHS -type f | xargs sed -i -e "s/${OLDHN//./\\.}/$NEWHN/g"
find $PATHS -type f | xargs sed -i -e "s/${OLDHN//./-}/${NEWHN//./-}/g"
find $PATHS -type f | xargs sed -i -e "s/$PRIVIP/$PUBIP/g"

for old in $(find $PATHS -type d | sort -r); do
  new=$(echo $old | sed -e "s/${OLDHN//./\\.}/$NEWHN/g")
  [ $old = $new ] || mv $old $new
done
for old in $(find $PATHS -type f | sort -r); do
  new=$(echo $old | sed -e "s/${OLDHN//./\\.}/$NEWHN/g")
  [ $old = $new ] || mv $old $new
done

rm -f /etc/dhcp/dhclient-eth0-up-hooks
sed -i -e "/$OLDHN/ d" /etc/hosts

sed -i -e "s/apps.example.com/apps.$PUBIP.xip.io/" /etc/openshift/master/master-config.yaml

python -c 'import random; print random.randint(11, 1000000000)' >/etc/openshift/master/ca.serial.txt
./openshift-aws-crypto.py $NEWHN

hostname $NEWHN

systemctl mask openshift-dns-intercept
sed -i -e '/hostsubnet/ d' /usr/local/libexec/openshift-node-ipcfg.py

start

oc delete node $OLDHN

oc get templates -n openshift -o json >/tmp/json
oc delete templates -n openshift --all
sed -e "s/${OLDHN//./\\.}/$NEWHN/g" /tmp/json | oc create -n openshift -f -

for i in docker-registry router; do
  oc delete dc $i
  oc delete svc $i
done

oadm registry --config=/etc/openshift/master/admin.kubeconfig --credentials=/etc/openshift/master/openshift-registry.kubeconfig --mount-host=/registry --service-account=infra --images='registry.access.redhat.com/openshift3/ose-${component}:${version}'

oadm router --credentials=/etc/openshift/master/openshift-router.kubeconfig --service-account=infra --images='registry.access.redhat.com/openshift3/ose-${component}:${version}'

oc delete pod $(oc get pods | grep image-registry | awk '{print $1;}')

for i in /home/demo/git/*; do
  pushd $i
  rm -rf .git
  git init
  git add -A
  git commit -m 'Initial commit'
  git remote add origin git://localhost/demo/$(basename $i)
  git push -f -u origin master
  popd
done

chown -R demo:demo /home/demo

echo 'Done.'
echo "https://$(hostname):8443/"
echo 'dont forget to set the password for the demo user, and warm up the EBS volume'

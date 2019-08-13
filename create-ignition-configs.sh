#!/bin/bash

ROOTCA=$(cat ssl/rootCA.crt | base64)
RESOLV=$(cat files/resolv.conf | base64)
REGISTRIES=$(cat files/registries.conf | base64)

rm -rf installer
mkdir installer

cp openstack-upi-install-config.yml installer/install-config.yaml
./openshift-install --dir=./installer create manifests

sed "s/###YOUR_CUSTOM_CA###/${ROOTCA}/g" templates/98-master-registries.yaml > installer/openshift/98-master-registries.yaml
sed "s/###YOUR_CUSTOM_CA###/${ROOTCA}/g" templates/98-worker-registries.yaml > installer/openshift/98-worker-registries.yaml

sed -i "s/###YOUR_CUSTOM_RESOLV###/${RESOLV}/g" installer/openshift/98-master-registries.yaml
sed -i "s/###YOUR_CUSTOM_RESOLV###/${RESOLV}/g" installer/openshift/98-worker-registries.yaml

sed -i "s/###YOUR_CUSTOM_REGISTRIES###/${REGISTRIES}/g" installer/openshift/98-master-registries.yaml
sed -i "s/###YOUR_CUSTOM_REGISTRIES###/${REGISTRIES}/g" installer/openshift/98-worker-registries.yaml

./openshift-install --dir=./installer create ignition-configs
cat installer/bootstrap.ign | jq . > installer/bootstrap2.ign
mv installer/bootstrap2.ign installer/bootstrap.ign

sed "s/###YOUR_CUSTOM_CA###/${ROOTCA}/g" templates/bootstrap_files.json > installer/bootstrap_files.json
sed -i "s/###YOUR_CUSTOM_RESOLV###/${RESOLV}/g" installer/bootstrap_files.json

cat installer/bootstrap.ign | jq ".storage.files += $(cat installer/bootstrap_files.json)" > installer/bootstrap.ign.temp
cat installer/bootstrap.ign.temp | jq ".systemd.units += $(cat bootstrap_units.json)" > installer/bootstrap.ign

mv ./installer/bootstrap.ign ./openstack-openshift-playbook/roles/loadbalancer/files/bootstrap.ign
mv ./installer/master.ign ./openstack-openshift-playbook/roles/openshift/files/master.ign
mv ./installer/worker.ign ./openstack-openshift-playbook/roles/openshift/files/worker.ign

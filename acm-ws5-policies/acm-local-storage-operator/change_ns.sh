#!/bin/bash
set -x

sed -i '' -e 's/1-openshift-storage/openshift-storage/g' openshift-storage-ns.yml
sed -i '' -e 's/1-openshift-storage/openshift-storage/g' openshift-storage-operatorgroup.yml
sed -i '' -e 's/1-openshift-storage/openshift-storage/g' odf-operator-subs.yml
sed -i '' -e 's/1-openshift-storage/openshift-storage/g' ocs-storagecluster.yml

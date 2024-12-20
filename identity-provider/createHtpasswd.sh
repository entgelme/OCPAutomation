#!/bin/bash
# htpasswd -c -B -b htpasswd workshop-admin <a password>
oc create secret generic localusers --from-file htpasswd=htpasswd -n openshift-config
oc adm policy add-cluster-role-to-user cluster-admin workshop-admin
oc get -o yaml oauth cluster > oauth.yaml
oc patch OAuth cluster  --patch-file OAuth-cluster-patch.yml --type merge
oc get OAuth cluster -o yaml

# test
# oc login -u workshop-admin -p <password>

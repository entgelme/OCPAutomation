#!/bin/bash

# expect MC_USER, pw and name of the managed cluster as well as API URL and Token of the hub as parameters

MC_USER=$1
MC_PASSWORD=$2
MC_CLUSTERFQDN=$3
HUB_APIURL=$4
HUB_APITOKEN=$5

if [ "$#" -ne 5 ]; then
    echo "Illegal number of parameters"
    echo -e "Usage $0 <MC-User> <MC-Password> <MC_Cluster-FQDN> <Hub API URL> <HUB_APITOKEN>\n"
    exit
#elif
# Check whether REQUESTFILE argument exists
# if not exit
fi

#############################################################################################
echo "Extract Managed Cluster's (MC) API URL and Token ..." 

MC_APIURL=https://api.$MC_CLUSTERFQDN:6443

oc login -u $MC_USER -p $MC_PASSWORD --server=$MC_APIURL --insecure-skip-tls-verify=false
MC_APITOKEN="$(oc whoami --show-token)"

echo "(Hub) Create namespace with the name of the managed cluster ..."

oc login --token $HUB_APITOKEN --server=$HUB_APIURL --insecure-skip-tls-verify=false
MC_CLUSTERNAME="$(echo $MC_CLUSTERFQDN | awk '{split($0, a, ".");print a[2]}' )"
oc new-project $MC_CLUSTERNAME

echo "Importing Managed Cluster '" $MC_CLUSTERNAME "' (API: "$MC_APIURL")"

#############################################################################################
echo "(Hub) generate managed-cluster.yaml and auto-import-secret.yaml with these values ..."
cat << EOF > managed-cluster.yaml
apiVersion: cluster.open-cluster-management.io/v1
kind: ManagedCluster
metadata:
  name: $MC_CLUSTERNAME
  labels:
    cloud: auto-detect
    vendor: auto-detect
spec:
  hubAcceptsClient: true
EOF

oc get secret $MC_CLUSTERNAME-import -n $MC_CLUSTERNAME -o jsonpath={.data.crds\\.yaml} | base64 --decode > klusterlet-crd.yaml
oc get secret $MC_CLUSTERNAME-import -n $MC_CLUSTERNAME -o jsonpath={.data.import\\.yaml} | base64 --decode > import.yaml

#############################################################################################
echo "(MC) Apply the extracted manifests on the managed cluster ..."
oc login --token $MC_APITOKEN --server=$MC_APIURL --insecure-skip-tls-verify=false
oc apply -f klusterlet-crd.yaml
oc apply -f import.yaml

#############################################################################################
echo "(Hub) Check status ..."
oc login --token $HUB_APITOKEN --server=$HUB_APIURL --insecure-skip-tls-verify=false
oc get managedcluster $MC_CLUSTERNAME

#############################################################################################
echo "Importing the klusterlet add-on ..."
cat << EOF > klusterlet-addon-config.yaml
apiVersion: agent.open-cluster-management.io/v1
kind: KlusterletAddonConfig
metadata:
  name: $MC_CLUSTERNAME
  namespace: $MC_CLUSTERNAME
spec:
  applicationManager:
    enabled: true
  certPolicyController:
    enabled: true
  iamPolicyController:
    enabled: true
  policyController:
    enabled: true
  searchCollector:
    enabled: true
EOF
oc get pod -n open-cluster-management-agent-addon

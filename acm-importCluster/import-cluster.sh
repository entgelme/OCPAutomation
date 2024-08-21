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
# Remember oc context for the managed cluster
MC_CONTEXT="$(oc config current-context)"

# Extract the managed clusters API token
MC_APITOKEN="$(oc whoami --show-token)"
echo "The managed cluster's API URL is:   "$MC_APIURL
echo "The managed cluster's API TOKEN is :"$MC_APITOKEN

# Login to hub cluster and remember this context to
oc login --token $HUB_APITOKEN --server=$HUB_APIURL --insecure-skip-tls-verify=false
HUB_CONTEXT="$(oc config current-context)"

MC_CLUSTERNAME="$(echo $MC_CLUSTERFQDN | awk '{split($0, a, ".");print a[1]}' )"
echo "(Hub) Create namespace with the name of the managed cluster: '"$MC_CLUSTERNAME"'"
oc new-project $MC_CLUSTERNAME

echo "(Hub) Importing Managed Cluster '"$MC_CLUSTERNAME"'"

#############################################################################################
echo "(Hub) generate managed-cluster.yaml and auto-import-secret.yaml with these values ..."
# automatic adds cluster to cluster set mCluster and sets label environment=test
cat << EOF > managed-cluster.yaml
apiVersion: cluster.open-cluster-management.io/v1
kind: ManagedCluster
metadata:
  name: $MC_CLUSTERNAME
  labels:
    cloud: auto-detect
    vendor: auto-detect
    cluster.open-cluster-management.io/clusterset: mcluster
    environment: test
spec:
  hubAcceptsClient: true
EOF
oc apply -f managed-cluster.yaml
# At this point something magic happens in ACM. Beside others a secret named $MC_CLUSTERNAME-import is created. 
sleep 5
# The ACM hub now waits for the connection request from the to-be-managed cluster

echo "(Hub) Extract klusterlet-crd.yaml and import.yaml manifests"
oc get secret $MC_CLUSTERNAME-import -n $MC_CLUSTERNAME -o jsonpath={.data.crds\\.yaml} | base64 --decode > klusterlet-crd.yaml
oc get secret $MC_CLUSTERNAME-import -n $MC_CLUSTERNAME -o jsonpath={.data.import\\.yaml} | base64 --decode > import.yaml

#############################################################################################
echo "(MC) Apply the extracted manifests on the managed cluster '"$MC_CLUSTERNAME" ..."
# Switch back to MC context
oc config use-context $MC_CONTEXT
oc apply -f klusterlet-crd.yaml
oc apply -f import.yaml

#############################################################################################
echo "(Hub) Check status ..."
# Switch back to HUB context
oc config use-context $HUB_CONTEXT
oc get managedcluster $MC_CLUSTERNAME

#############################################################################################
echo "Importing the klusterlet add-on ..."
cat << EOF > klusterlet-addon-config.yaml
apiVersion: agent.open-cluster-management.io/v1
kind: KlusterletAddonConfig
metadata:
  name: $MC_CLUSTERNAME
  namespace: $MC_CLUSTERNAME
  clusterLabels:
    name: $MC_CLUSTERNAME
    cloud: auto-detect
    vendor: auto-detect
    cluster.open-cluster-management.io/clusterset: mcluster
    environment: test
spec:
  clusterLabels:
    name: test
    cloud: auto-detect
    vendor: auto-detect
    cluster.open-cluster-management.io/clusterset: mcluster
    environment: test
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
oc apply -f klusterlet-addon-config.yaml
oc get pod -n open-cluster-management-agent-addon



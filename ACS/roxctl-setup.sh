#!/bin/bash
# Assumption: the RHACS central is already in place at the hub cluster
# expect the managed cluster name as parameter

MC_APIURL=$1
MC_APITOKEN=$2
ROXCTL_ACCESS_TOKEN_FILE=$3
CLUSTER_INIT_BUNDLE_FILE=$4

if [ "$#" -ne 4 ]; then
    echo "Illegal number of parameters"
    echo -e "Usage $0 <MC API URL incl. port> <MC API Token> <path-to-roxctl-access-token-file> <cluster init bundle file>\n"
    exit
fi

MC_CLUSTERNAME="$(echo $MC_APIURL | awk '{split($0, a, "api.");print a[2]}' |awk '{split($0, a, ":");print a[1]}' )" && echo $MC_CLUSTERNAME 

echo Setting up the RHACS sensor on cluster $MC_CLUSTERNAME
echo "Assuming, you are already logged in to the Hub Cluster"
oc cluster-info | grep Kubernetes
echo -n "Using rocctl v" 
roxctl version 

echo -n "RHACS admin password: "
oc -n stackrox get secret central-htpasswd -o go-template='{{index .data "password" | base64decode}}' && echo ""

export ROX_ENDPOINT="$(oc -n stackrox get route central -o jsonpath="{.status.ingress[0].host}"):443"
echo "\$ROX_ENDPOINT: "$ROX_ENDPOINT

# Assuming ROX API Token has been generated before and put to the file roxctl-access-token
export ROX_API_TOKEN="$(cat $ROXCTL_ACCESS_TOKEN_FILE)"

# Generate cluster_init_bundle (uncomment next line, if cluster_init_bundle has not yet been generated on this hub/central)
#roxctl -e "$ROX_ENDPOINT" central init-bundles generate cluster_init_bundle  --output-secrets cluster_init_bundle.yaml --insecure-skip-tls-verify=true

# Patch acs-host address (running 'central') to sensor.tls 
# The secured cluster will read it out (see ACM policy 'policy-advanced-managed-cluster-security')
# This patch is a customized solution and extends the ootb installation procedure (for the sake of scripting)

yq  '(. | select(.metadata.name == "sensor-tls") | .stringData.acs-host) = "'$ROX_ENDPOINT'"' $CLUSTER_INIT_BUNDLE_FILE > cluster_init_bundle_adjusted.yaml 

# Remember oc context
CURRENT_CONTEXT="$(oc config current-context)"

# first login to secured cluster
oc login --token $MC_APITOKEN --server=$MC_APIURL --insecure-skip-tls-verify=true < "y"|grep Logged

# then apply the cluster_init_bundle_adjusted.yaml there
echo "Applying cluster_init_bundle_adjusted.yaml on cluster '"$MC_CLUSTERNAME"'" 
oc apply -f cluster_init_bundle_adjusted.yaml -n stackrox

# Switch back to original context
oc config use-context $CURRENT_CONTEXT
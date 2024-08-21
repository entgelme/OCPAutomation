#!/bin/bash
# Assumption: the RHACS central is already in place at the hub cluster
# expect the managed cluster name as parameter

MC_CLUSTERNAME=$1

if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
    echo -e "Usage $0 <MC Name>\n"
    exit
#elif
# Check whether REQUESTFILE argument exists
# if not exit
fi


echo Setting up the RHACS sensor on cluster $1
echo -n "Using rocctl v" 
roxctl version

echo -n "RHACS admin password: "
oc -n stackrox get secret central-htpasswd -o go-template='{{index .data "password" | base64decode}}' && echo ""

export ROX_ENDPOINT="$(oc -n stackrox get route central -o jsonpath="{.status.ingress[0].host}"):443"
echo "\$ROX_ENDPOINT: "$ROX_ENDPOINT

# Assuming ROX API Token has been generated before and put to the file roxctl-access-token
export ROX_API_TOKEN="$(cat roxctl-access-token)"

# Generate cluster_init_bundle
#roxctl -e "$ROX_ENDPOINT" central init-bundles generate cluster_init_bundle  --output-secrets cluster_init_bundle.yaml

# Patch acs-host address (running 'central') to sensor.tls 
# The secured cluster will read it out (see ACM policy 'policy-advanced-managed-cluster-security')
# This patch is a customized solution and extends the ootb installation procedure (for the sake of scripting)

yq  '(. | select(.metadata.name == "sensor.tls") | .stringData.acs-host) = "'$ROX_ENDPOINT'"' cluster_init_bundle.yaml > cluster_init_bundle_adjusted.yaml 
# with all secured clusters
# first login to secured cluster
# then: 
# oc apply -f cluster_init_bundle_adjusted.yaml -n stackrox
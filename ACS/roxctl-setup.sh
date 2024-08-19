#!/bin/bash
echo -n "RHACS admin password: "
oc -n stackrox get secret central-htpasswd -o go-template='{{index .data "password" | base64decode}}' && echo ""

export ROX_ENDPOINT="$(oc -n stackrox get route central -o jsonpath="{.status.ingress[0].host}")"
echo "\$ROX_ENDPOINT: "$ROX_ENDPOINT

yq  '.stringData.acs-host = "'$ROX_ENDPOINT'"' cluster_init_bundle.yaml > cluster_init_bundle_adjusted.yaml 
yq  '(. | select(.metadata.name == "sensor.tls") | .stringData.acs-host) = "'$ROX_ENDPOINT'"' cluster_init_bundle.yaml > cluster_init_bundle_adjusted.yaml 
# with all secured clusters
# first login to secured cluster
# then: 
# oc apply -f cluster_init_bundle_adjusted.yaml -n stackrox
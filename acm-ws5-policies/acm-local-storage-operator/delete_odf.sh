#!/bin/bash
set -x

# delete ODF ressources

# TODO delete cluster resource

oc delete Subscription odf-operator -n openshift-storage
oc delete Subscription ocs-operator -n openshift-storage
oc delete OperatorGroup openshift-storage-operatorgroup -n openshift-storage
oc delete Namespace openshift-storage --force

oc delete LocalVolumeSet local-block -n openshift-local-storage

oc delete LocalVolumeDiscovery auto-discover-devices -n openshift-local-storage

oc label node --all cluster.ocs.openshift.io/openshift-storage-

oc delete Subscription local-storage-operator -n openshift-local-storage

oc delete OperatorGroup local-operator-group -n openshift-local-storage

oc delete Namespace openshift-local-storage



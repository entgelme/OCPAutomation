#!/bin/bash
set -x

echo ODF Setup
# from https://access.redhat.com/articles/5692201
#    Step 1: Installing the Local Storage Operator

CLUSTER_NAME="cp4bamig1d.cp.fyre.ibm.com"
OC_VERSION=$(oc version -o yaml | grep openshiftVersion | grep -o '[0-9]*[.][0-9]*' | head -1)
echo "Deploying to OCP $OC_VERSION"

## Create the openshift-local-storage namespace.
OCS_NS_FILE=openshift-local-storage-ns.yml
if [ ! -f "$OCS_NS_FILE" ]; then
    echo "Missing file $OCS_NS_FILE"
    exit
else 
    # apply the yaml file
    echo "Applying file $OCS_NS_FILE"
    oc apply -f $OCS_NS_FILE
fi


## Create the openshift-local-storage for Local Storage Operator.
### Subscribe to the local-storage-operator.
OCS_SUBS_FILE=local-storage-operator-subs.yml
if [ ! -f "$OCS_SUBS_FILE" ]; then
    echo "Missing file $OCS_SUBS_FILE"
else
    # then apply the yaml file
    echo "Applying file $OCS_SUBS_FILE"
    oc apply -f $OCS_SUBS_FILE
fi

echo "Please be patient ..."
sleep 60
oc get pods -n openshift-local-storage 
oc get csvs -n openshift-local-storage



##    Step 3: Installing OpenShift Data Foundation
###    Install Operator
#### Create the openshift-storage namespace.
OCP_STORAGE_NS=openshift-storage-ns.yml
if [ ! -f "$OCP_STORAGE_NS" ]; then
    echo "Missing file $OCP_STORAGE_NS"
else
    # then apply the yaml file
    echo "Applying file $OCP_STORAGE_NS"
    oc apply -f $OCP_STORAGE_NS
fi

#### Create the openshift-storage-operatorgroup for Operator.
OCP_STORAGE_OG=openshift-storage-operatorgroup.yml
if [ ! -f "$OCP_STORAGE_OG" ]; then
    echo "Missing file $OCP_STORAGE_OG"
else
    # then apply the yaml file
    echo "Applying file $OCP_STORAGE_OG"
    oc apply -f $OCP_STORAGE_OG
fi

#### Subscribe to the ocs-operator.
#OCS_OPERATOR_SUBS=ocs-operator-subs.yml
#if [ ! -f "$OCS_OPERATOR_SUBS" ]; then
#    echo "Missing file $OCS_OPERATOR_SUBS"
#else
#    # then apply the yaml file
#    echo "Applying file $OCS_OPERATOR_SUBS"
#    oc apply -f $OCS_OPERATOR_SUBS
#fi

# TODO: check: in interactive installation 2 additional subscriptions will be generated
# mcg-operator-stable-4.14-redhat-operators-openshift-marketplace.yml
# odf-csi-addons-operator-stable-4.14-redhat-operators-openshift-marketplace.yml

#### Subscribe to the odf-operator for version 4.9 or above
ODF_OPERATOR_SUBS=odf-operator-subs.yml
if [ ! -f "$ODF_OPERATOR_SUBS" ]; then
    echo "Missing file $ODF_OPERATOR_SUBS"
else
    # then apply the yaml file
    echo "Applying file $ODF_OPERATOR_SUBS"
    oc apply -f $ODF_OPERATOR_SUBS
fi

sleep 60



# the following part is done by the ODF-Operater himself in the course of creating a storagecluster 
# doesn't work here in headless mode
# TODO: why?
if false; then

    echo -e "\nPreparing nodes"

    #    Step 2: Preparing Nodes
    OCP_STORAGE_WORKER=('worker0' 'worker1' 'worker2')
    
    for node in "${OCP_STORAGE_WORKER[@]}"
    do
        echo "Labeling node $node.$CLUSTER_NAME"
        oc label node $node.$CLUSTER_NAME cluster.ocs.openshift.io/openshift-storage=''
    done

    ## Create the LocalVolumeDiscovery resource (?)
        #    Only for OpenShift Data Foundation and OpenShift Container Storage v4.6 and above
    ###    Auto Discovering Devices and creating Persistent Volumes
    echo -e "\Auto Discovering Devices"
    OCS_DISCOVER_FILE=auto-discover-devices.yml
    if [ ! -f "$OCS_DISCOVER_FILE" ]; then
        echo "Missing file $OCS_DISCOVER_FILE"
    else
        # then apply the yaml file
        echo "Applying file $OCS_DISCOVER_FILE"
        oc apply -f $OCS_DISCOVER_FILE
    fi

    oc get localvolumediscoveries -n openshift-local-storage
    oc get localvolumediscoveryresults -n openshift-local-storage

    #    Create LocalVolumeSet (?)

    echo -e "\Create LocalVolumeSet"
    OCS_LOCALVOLUMESET=localvolumeset.yml
    if [ ! -f "$OCS_LOCALVOLUMESET" ]; then
        echo "Missing file $OCS_LOCALVOLUMESET"
    else
        # then apply the yaml file
        echo "Applying file $OCS_LOCALVOLUMESET"
        oc apply -f $OCS_LOCALVOLUMESET
    fi
else
    echo "skipping creation of 'Auto Discovering Devices' and 'LocalVolumeSet'"
fi

if false; then
    #    Create Cluster
    ODF_STORAGECLUSTER=ocs-storagecluster.yml
    if [ ! -f "$ODF_STORAGECLUSTER" ]; then
        echo "Missing file $ODF_STORAGECLUSTER"
    else
        # then apply the yaml file
        echo "Applying file $ODF_STORAGECLUSTER"
        oc apply -f $ODF_STORAGECLUSTER
    fi
else
    echo "skipping creation of 'StorageCluster'. Please perform that in the OCP WebConsole>Installed Operators>ODF Operator>Create StorageCluster"

fi
#    Step 4: Verifying the Installation
#    Step 5: Creating test CephRBD PVC and CephFS PVC.

oc get pods -n openshift-local-storage | grep "diskmaker-manager"
oc get pv -n openshift-local-storage
read -p 'Do you see the PVs provided by OCS? Then hit a key to continue, else something went wrong ... ' -n 1 -s


cd ~

echo -e "\nDONE\n"

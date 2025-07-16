#!/bin/bash

# Script to automate Dynamic NFS Provisioning in Red Hat OpenShift, running on the NFS server itself.
# Modified based on: https://muafzal.medium.com/dynamic-nfs-provisioning-in-red-hat-openshift-b35e8bb05984

# --- Variables ---
NFS_EXPORT_PATH="/nfs/exports/myshare"
STORAGE_CLASS_NAME="nfs-dynamic"
NAMESPACE="default"
NFS_SERVER_IP=$(ip a | grep "inet 10\." | awk '{print $2}' | cut -d'/' -f1) # Get local IP on 10. network
NFS_PROVISIONER_IMAGE="registry.k8s.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2" #Use latest stable version
# --- End Variables ---

# --- Install kubectl and oc if needed ---
if ! command -v kubectl &> /dev/null; then
  echo "kubectl not found. Installing..."
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
  echo "kubectl installed."
fi

if ! command -v oc &> /dev/null; then
  echo "oc not found. Installing..."
  curl -LO "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz"
  tar xvf openshift-client-linux.tar.gz
  sudo mv oc /usr/local/bin/
  rm openshift-client-linux.tar.gz
  echo "oc installed."
fi

# --- Check oc login ---

if [ -f /root/auth/kubeconfig ]; then
  export KUBECONFIG=/root/auth/kubeconfig
fi

if ! oc whoami &> /dev/null; then
  echo "Please log in to your OpenShift cluster using 'oc login' first."
  unset KUBECONFIG
  exit 1
fi

# 1. Install NFS utilities on the NFS server (if not already installed)
sudo dnf install -y nfs-utils || sudo yum install -y nfs-utils || sudo apt-get install -y nfs-kernel-server

# 2. Configure the NFS export on the NFS server
sudo mkdir -p "${NFS_EXPORT_PATH}"
echo "${NFS_EXPORT_PATH} *(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports
sudo exportfs -ra
##### change permission to be usable by nfs provisioner pod
chmod a+rwx ${NFS_EXPORT_PATH}

# 3. Create the service account, cluster role, and cluster role binding
cat <<EOF | oc apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nfs-client-provisioner
  namespace: ${NAMESPACE}
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-client-provisioner-runner
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
  - apiGroups: [""] # Add these rules
    resources: ["endpoints"] # Add these rules
    verbs: ["get", "list", "watch", "create", "update", "patch"] # Add these rules
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: run-nfs-client-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    namespace: ${NAMESPACE}
roleRef:
  kind: ClusterRole
  name: nfs-client-provisioner-runner
  apiGroup: rbac.authorization.k8s.io
EOF

# 4. Create the deployment
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-client-provisioner
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: nfs-client-provisioner
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          image: ${NFS_PROVISIONER_IMAGE}
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: k8s-sigs.io/nfs-subdir-external-provisioner
            - name: NFS_SERVER
              value: ${NFS_SERVER_IP}
            - name: NFS_PATH
              value: ${NFS_EXPORT_PATH}
      volumes:
        - name: nfs-client-root
          nfs:
            server: ${NFS_SERVER_IP}
            path: ${NFS_EXPORT_PATH}
EOF

# 5. Create the storage class
cat <<EOF | oc apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${STORAGE_CLASS_NAME}
provisioner: k8s-sigs.io/nfs-subdir-external-provisioner
parameters:
  path: /
  archiveOnDelete: "false"
EOF

echo "Dynamic NFS provisioning setup complete."
echo "StorageClass: ${STORAGE_CLASS_NAME}"
echo "Namespace: ${NAMESPACE}"
echo "NFS Server: ${NFS_SERVER_IP}:${NFS_EXPORT_PATH}"